# vault-lite — state segmentado, sem cluster dedicado

Configuração declarativa de uma única instância **HashiCorp Vault OSS
flat** (sem namespaces, sem cluster dedicado, sem licença Enterprise), com
**state Terraform segmentado por entidade de negócio** — a mesma meta de
`vault-yepa/`, atingida sem depender de infraestrutura de cluster.

Para os fundamentos que este módulo compartilha com `vault/` e
`vault-yepa/` (por que secrets não passam pelo Terraform, a convenção de KV
v2, as sutilezas de ACL, como o login GitHub funciona), ver
**[`../vault/README.md`](../vault/README.md)** — não duplicado aqui.

> Comentários no código estão em inglês; documentação em português.

---

## Sumário

- [Por que este módulo existe](#por-que-este-módulo-existe)
- [Arquitetura](#arquitetura)
- [Estrutura de diretórios](#estrutura-de-diretórios)
- [Comparando com vault/ e vault-yepa/](#comparando-com-vault-e-vault-yepa)
- [Pré-requisitos](#pré-requisitos)
- [Executando](#executando)
- [Como adicionar uma entidade](#como-adicionar-uma-entidade)
- [Riscos e limitações conhecidas](#riscos-e-limitações-conhecidas)

---

## Por que este módulo existe

Ver **[`docs/adr/0001-mount-path-por-entidade-sem-namespaces.md`](docs/adr/0001-mount-path-por-entidade-sem-namespaces.md)**
para a decisão completa. Resumo:

- `vault-yepa/` segmenta state usando namespaces do Vault **Enterprise** —
  o que pressupõe um cluster dedicado (HA, licença, réplicas).
- Aqui o pedido foi "estratégia empresarial parecida, mas sem vault
  dedicated": uma única instância Vault **OSS**, pequena, sem o
  compromisso operacional de um cluster.
- **HCP Vault Secrets** (a resposta óbvia — SaaS sem cluster nenhum) foi
  avaliado e descartado: teve *end-of-sale* em 30/06/2025 e **end-of-life
  em 01/07/2026** — já não existe. A HashiCorp orienta migrar para HCP
  Vault Dedicated ou Vault OSS self-hosted. Ficamos com a segunda opção.
- Sem namespaces, isolamento entre entidades passa a ser por **path de
  mount + disciplina de policy**, não por fronteira de plataforma. Esse é
  o trade-off central — ver "Riscos" abaixo antes de adotar isto em
  produção.

## Arquitetura

```
                    1 instância Vault OSS — flat, sem namespace
        ┌───────────────────────────────┬───────────────────────────────┐
        │  entities/apps/                │  entities/platform/            │
        │  workspace: vault-lite-apps    │  workspace: vault-lite-platform│
        │  state 1 de 2 — independente   │  state 2 de 2 — independente   │
        │                                 │                                 │
        │  modules/vault-entity           │  modules/vault-entity           │
        │   ├─ GitHub auth: github-apps   │   ├─ GitHub auth: github-platform│
        │   ├─ KV v2 mount: apps/         │   ├─ KV v2 mount: platform/     │
        │   └─ policies/*.hcl             │   └─ policies/*.hcl             │
        └───────────────────────────────┴───────────────────────────────┘
```

Nenhuma seta entre os dois states: cada um cria seu próprio mount e seu
próprio auth method, do zero, sem ler nada do outro. A única coisa que os
mantém sem colidir é `docs/spec/entidades.md` + o job `path-collisions` do
CI — ver ADR 0001.

## Estrutura de diretórios

```
vault-lite/
├── modules/
│   └── vault-entity/            idêntico a vault-yepa/modules/vault-entity/
│       ├── auth.tf              instancia ./auth
│       ├── auth/                 GitHub auth backend
│       ├── policies.tf          descobre policies em path.root/policies/*.hcl
│       ├── secret-engines.tf    mounts KV v2, a partir de var.kv_mounts
│       ├── locals.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── entities/
│   ├── apps/                     root module — workspace vault-lite-apps
│   │   ├── main.tf                module "this" { source = ../../modules/vault-entity }
│   │   ├── providers.tf           sem `namespace` — Vault flat
│   │   ├── backend.tf
│   │   ├── policies/              developers.hcl, production-read.hcl, sre.hcl
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   └── platform/                  mesma forma
│       └── policies/              platform-admins.hcl
│
└── docs/
    ├── adr/0001-...md             por que sem namespace, sem core
    └── spec/entidades.md          registro de paths reservados
```

Note o que **não existe** aqui em relação a `vault-yepa/`: não há `core/`,
não há `remote_state.tf`, não há `namespace` em nenhum `providers.tf`.

## Comparando com vault/ e vault-yepa/

| | `vault/` | `vault-yepa/` | `vault-lite/` |
|---|---|---|---|
| Vault | OSS, flat | **Enterprise**, namespaces | OSS, flat |
| Cluster dedicado | não provisionado aqui (mas assumido) | sim, pressuposto | não — instância única, leve |
| State | **único** | segmentado, 3 states (core + 2 entidades) | segmentado, **2 states** (sem core) |
| Isolamento entre entidades | nenhum — 1 dono só | namespace (plataforma) | path de mount + policy (convenção) |
| Coordenação entre states | n/a | `terraform_remote_state` (core → entidade) | nenhuma — states independentes |
| Quando escolher | instalação pequena, 1 dono | multi-tenant real, licença Enterprise disponível | multi-tenant leve, sem orçamento/operação de cluster |

## Pré-requisitos

- Terraform >= 1.5.
- Uma instância Vault **OSS** (ou Enterprise usada sem namespaces) já no ar
  — o bootstrap do binário/cluster não é gerenciado aqui, mesma regra de
  `vault/` e `vault-yepa/`.
- Uma organização HCP Terraform, com dois workspaces criados:
  `vault-lite-apps`, `vault-lite-platform`.
- Um token Vault com permissão para `sys/mounts` e `sys/auth`, escopado ao
  prefixo de path daquela entidade sempre que possível.

## Executando

Cada diretório em `entities/` é um root module independente, sem ordem de
apply entre eles (diferente de `vault-yepa/`, que exige `core` primeiro):

```bash
cd vault-lite/entities/apps
terraform init
terraform plan
terraform apply

cd ../platform
terraform init
terraform plan
terraform apply
```

Antes do primeiro `terraform init`, troque `organization = "yepa"` pelo
nome real da sua organização HCP Terraform em cada `backend.tf` — o bloco
`cloud {}` não aceita `var.*`.

Login humano:

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_AUTH_GITHUB_TOKEN="github_pat_xxxxx"   # PAT com read:org

vault login -method=github -path=github-apps       # entidade apps
vault login -method=github -path=github-platform    # entidade platform
```

## Como adicionar uma entidade

1. Escolha um `kv_mount_path` e um `github_auth_path` que não colidam com
   nenhuma linha existente em `docs/spec/entidades.md` — essa tabela é a
   fonte de verdade, atualize-a como parte do mesmo PR.
2. Copie um diretório existente em `entities/` (ex.: `entities/apps`) para
   `entities/<nova>/`.
3. Ajuste `main.tf` (nome da chave em `kv_mounts`, mapeamento de GitHub
   Teams) e os defaults de `github_auth_path` / `kv_mount_path` em
   `variables.tf`.
4. Ajuste `backend.tf` para um novo workspace HCP Terraform (ex.:
   `vault-lite-<nova>`) e crie esse workspace.
5. Escreva `policies/*.hcl` para a realidade daquela entidade — nunca use
   um path curinga (`+` ou `*`) fora do próprio `${mount_paths.<chave>}`.
6. `terraform init && terraform plan && terraform apply` dentro do novo
   diretório. O CI (`path-collisions`) barra o PR se os paths colidirem
   com os de outra entidade.

## Riscos e limitações conhecidas

Além dos riscos já documentados em
[`../vault/README.md#riscos-e-limitações-conhecidas`](../vault/README.md#riscos-e-limitações-conhecidas):

**1. Isolamento é por convenção de policy, não por plataforma.** Este é o
risco central do desenho — ver ADR 0001. Nada no Vault impede uma policy
futura de conceder acesso a um mount de outra entidade; a única defesa é
disciplina de revisão + o comentário em cada `policies/*.hcl` apontando
para este risco. Se isso deixar de ser aceitável, a resposta é voltar para
`vault-yepa/` (namespaces) ou migrar para um secrets manager de cloud
provider com isolamento por conta/projeto.

**2. `sys/mounts` e `sys/auth` são globais.** Qualquer policy com `read` /
`list` nesses paths (ex.: `sre`, `platform-admins`) enxerga os NOMES de
mount e auth method de toda entidade, não só a própria — nunca o conteúdo.
Mesma troca consciente do item 5 de `vault/README.md`, só que agora
também através de fronteiras de entidade.

**3. Sem reserva de path via Terraform.** Um valor de `kv_mount_path` ou
`github_auth_path` passado fora do default (via `terraform.tfvars` ou
variável de workspace) não é verificado pelo CI, só os defaults em
`variables.tf` são. Colisão nesse caso só aparece no `apply` (Vault
recusa criar um mount ou auth method em path já ocupado) — não é
silencioso, mas também não é barrado no PR.

**4. Um único ponto de falha.** Sem cluster, sem HA: a instância caindo
tira o acesso a TODAS as entidades ao mesmo tempo — diferente de um
cluster Enterprise com réplicas. Aceitável para a escala que motivou "sem
vault dedicated"; reavalie se isso deixar de ser verdade.
