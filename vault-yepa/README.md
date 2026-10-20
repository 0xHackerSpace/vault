# vault-yepa — Vault empresarial, state segmentado por entidade

Configuração declarativa do HashiCorp Vault **Enterprise**, via Terraform,
para operação multi-tenant: cada entidade de negócio (time/produto) tem seu
próprio namespace Vault e seu próprio state Terraform, isolado dos demais.

Para os fundamentos que este módulo compartilha com `vault/` (por que
secrets não passam pelo Terraform, a convenção de KV v2, as duas
sutilezas de ACL, como o login GitHub funciona), ver
**[`../vault/README.md`](../vault/README.md)** — não duplicado aqui.

> Comentários no código estão em inglês; documentação em português.

---

## Sumário

- [Por que state segmentado](#por-que-state-segmentado)
- [Arquitetura](#arquitetura)
- [Estrutura de diretórios](#estrutura-de-diretórios)
- [Pré-requisitos](#pré-requisitos)
- [Configurando os workspaces HCP Terraform](#configurando-os-workspaces-hcp-terraform)
- [Ordem de apply](#ordem-de-apply)
- [Executando](#executando)
- [Como adicionar uma entidade](#como-adicionar-uma-entidade)
- [Terraform state](#terraform-state)
- [Riscos e limitações conhecidas](#riscos-e-limitações-conhecidas)

---

## Por que state segmentado

Ver **[`docs/adr/0001-state-segmentado-por-entidade-de-negocio.md`](docs/adr/0001-state-segmentado-por-entidade-de-negocio.md)**
para a decisão completa e os trade-offs. Resumo:

- Um state único vira um ponto de lock e de blast radius compartilhado por
  toda a organização.
- Aqui, cada entidade de negócio (`entities/<nome>/`) tem seu próprio
  namespace Vault Enterprise e seu próprio workspace HCP Terraform — logo,
  seu próprio state, sua própria permissão de acesso, seu próprio `apply`.
- Uma camada `core/`, mínima e compartilhada, existe só porque criar um
  namespace é uma operação de namespace-pai (root) — nada mais estrutural
  vive lá.

## Arquitetura

```
                    ┌─────────────────────────────┐
                    │  core/  (workspace: vault-yepa-core)
                    │  namespace: root              │
                    │  → vault_namespace "apps"      │
                    │  → vault_namespace "platform"  │
                    └───────────┬─────────┬─────────┘
                                │         │
              outputs.namespace_paths (terraform_remote_state)
                                │         │
              ┌─────────────────▼──┐   ┌──▼──────────────────┐
              │ entities/apps/      │   │ entities/platform/   │
              │ workspace:          │   │ workspace:            │
              │  vault-yepa-apps    │   │  vault-yepa-platform  │
              │ namespace: apps     │   │ namespace: platform   │
              │                     │   │                        │
              │ modules/vault-entity│   │ modules/vault-entity   │
              │  ├─ GitHub auth     │   │  ├─ GitHub auth        │
              │  ├─ KV v2 "apps"    │   │  ├─ KV v2 "platform"   │
              │  └─ policies/*.hcl  │   │  └─ policies/*.hcl     │
              └─────────────────────┘   └────────────────────────┘
```

Cadeia de autorização, dentro de UMA entidade (idêntica à do `vault/`
original, só que confinada ao namespace daquela entidade):

```
GitHub Team ──(slug)──▶ Vault GitHub Auth ──▶ Vault Policy ──▶ KV v2 mount
                         (dentro do namespace da entidade)
```

Um token emitido no namespace `apps` não enxerga nada no namespace
`platform`, e vice-versa — isolamento é a propriedade central deste desenho,
não um efeito colateral.

## Estrutura de diretórios

```
vault-yepa/
├── core/                       root module — cria os namespaces
│   ├── namespaces.tf
│   ├── providers.tf            sem `namespace` (opera em root)
│   ├── backend.tf              cloud { workspaces { name = "vault-yepa-core" } }
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
│
├── modules/
│   └── vault-entity/           child module compartilhado, SEM state próprio
│       ├── auth.tf             instancia ./auth
│       ├── auth/                GitHub auth backend (idêntico a vault/auth/)
│       ├── policies.tf         descobre policies em path.root/policies/*.hcl
│       ├── secret-engines.tf   mounts KV v2, a partir de var.kv_mounts
│       ├── locals.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── entities/
│   ├── apps/                   root module — workspace vault-yepa-apps
│   │   ├── main.tf              module "this" { source = ../../modules/vault-entity }
│   │   ├── remote_state.tf      lê namespace_paths["apps"] de core/
│   │   ├── providers.tf         namespace = <lido de core/>
│   │   ├── backend.tf
│   │   ├── policies/            developers.hcl, production-read.hcl, sre.hcl
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   └── platform/                mesma forma, namespace "platform"
│       └── policies/            platform-admins.hcl
│
└── docs/
    ├── adr/0001-...md           por que state segmentado por entidade
    └── spec/entidades.md        inventário de entidades
```

## Pré-requisitos

- Terraform >= 1.5.
- **Vault Enterprise** com o recurso de namespaces habilitado (licença
  Enterprise). `vault_namespace` não existe em Vault OSS.
- Uma organização HCP Terraform, com três workspaces criados (ver abaixo).
- Um token Vault com permissão para `sys/namespaces/*` (para `core`) e, por
  namespace, permissão para `sys/mounts`, `sys/auth` e `sys/policies`
  **dentro daquele namespace** (para cada `entities/<nome>/`).

## Configurando os workspaces HCP Terraform

1. Crie os três workspaces na sua organização HCP Terraform:
   `vault-yepa-core`, `vault-yepa-apps`, `vault-yepa-platform`.
2. Em cada `backend.tf` deste repositório, troque `organization = "yepa"`
   pelo nome real da sua organização HCP Terraform — o bloco `cloud {}` é
   avaliado antes de qualquer variável, então não é parametrizável por
   `var.*`.
3. Em `vault-yepa-core`, habilite **Remote state sharing** para
   `vault-yepa-apps` e `vault-yepa-platform` (workspace `vault-yepa-core` →
   Settings → Sharing). Sem isso, o `data "terraform_remote_state"` em
   `entities/<nome>/remote_state.tf` falha no `plan`.
4. Em cada workspace, defina `VAULT_ADDR` e `VAULT_TOKEN` como *environment
   variables* (marque `VAULT_TOKEN` como sensitive) — nunca como Terraform
   variables.

## Ordem de apply

Terraform não impõe `depends_on` entre states diferentes. A ordem é uma
regra operacional:

1. **`core`** primeiro — sem os namespaces, `entities/<nome>/` não tem onde
   operar (`data.terraform_remote_state.core.outputs.namespace_paths[...]`
   falha).
2. **`entities/<nome>/`** depois, em qualquer ordem entre si — cada um só
   depende de `core`, nunca de outro `entities/<outro>/`.

Remover uma entidade é o inverso: `terraform destroy` em
`entities/<nome>/` antes de tirar a entrada de `core/variables.tf` — um
namespace com recursos filhos não é removido pelo Vault.

## Executando

Cada diretório (`core/`, `entities/apps/`, `entities/platform/`) é um root
module independente — rode os comandos de dentro dele, não na raiz de
`vault-yepa/`.

```bash
cd vault-yepa/core
terraform init
terraform plan
terraform apply

cd ../entities/apps
terraform init
terraform plan
terraform apply

cd ../platform
terraform init
terraform plan
terraform apply
```

Login humano, agora namespace-aware:

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_AUTH_GITHUB_TOKEN="github_pat_xxxxx"   # PAT com read:org
export VAULT_NAMESPACE="apps"                        # ou "platform"

vault login -method=github
```

## Como adicionar uma entidade

1. Adicione o nome em `core/variables.tf` (`var.entities`, ou na variável
   equivalente do workspace `vault-yepa-core`) e aplique `core` — isso cria
   o namespace.
2. Copie um diretório existente em `entities/` (ex.: `entities/apps`) para
   `entities/<nova>/`.
3. Ajuste `remote_state.tf` e `providers.tf` para o nome da nova entidade
   (troque a chave `"apps"` por `"<nova>"` em
   `namespace_paths["apps"]`).
4. Ajuste `backend.tf` para um novo workspace HCP Terraform (ex.:
   `vault-yepa-<nova>`), crie esse workspace e habilite remote state
   sharing a partir de `vault-yepa-core`.
5. Ajuste `main.tf` (mount(s) KV e mapeamento de GitHub Teams) e
   `policies/*.hcl` para a realidade daquela entidade.
6. Registre a entidade em `docs/spec/entidades.md`.
7. `terraform init && terraform plan && terraform apply` dentro do novo
   diretório.

Adicionar uma policy, um GitHub Team ou um mount **dentro** de uma entidade
já existente segue exatamente o "Como expandir" de
[`../vault/README.md`](../vault/README.md#como-expandir) — a única
diferença é que o arquivo de policy vive em `entities/<nome>/policies/`, e o
mount é referenciado nos templates como `${mount_paths.<chave>}` em vez de
`${kv_mount_path}`.

## Terraform state

Cada um dos três states é sensível pelo mesmo motivo descrito em
[`../vault/README.md#terraform-state`](../vault/README.md#terraform-state):
tudo que passa pelo Terraform vai em texto claro para o state. Aqui isso é
verdade **por entidade**: o state de `entities/apps/` carrega as policies e
a configuração de auth apenas daquela entidade — nunca as de `platform`.
Isso é justamente o ganho de segmentar: quem tem acesso ao workspace
`vault-yepa-apps` nunca teve, nem precisa ter, acesso ao state de
`platform`.

O state de `core` é o mais sensível dos três apesar de ser o menor: quem o
controla decide quais namespaces existem.

## Riscos e limitações conhecidas

Além dos riscos já documentados em
[`../vault/README.md#riscos-e-limitações-conhecidas`](../vault/README.md#riscos-e-limitações-conhecidas)
(saída de rede para a API do GitHub, PAT como credencial de longa duração,
disponibilidade dependente do GitHub, audit device não gerenciado aqui,
bootstrap do Vault fora de escopo), específicos deste desenho:

**1. Sem leitura cross-namespace por padrão.** Ver ADR 0001 — a policy
`platform-admins` não lê secrets de `apps`, diferente da
`platform-engineering` do módulo `vault/` original. Se suporte cross-time
for necessário, desenhe-o deliberadamente (ex.: namespace dedicado com
grants explícitos em cada entidade), não como reintrodução acidental de um
mount compartilhado.

**2. Ordem de apply não é garantida pela ferramenta.** `core` antes de
`entities/<nome>/` é uma regra operacional (ver acima), não algo que o
Terraform impõe entre states/workspaces diferentes. Automatizar isso (run
triggers do HCP Terraform, por exemplo) é uma extensão natural quando este
setup for promovido para produção.

**3. Remote state sharing é uma dependência de configuração do HCP
Terraform, fora do código.** Um workspace de entidade sem "remote state
sharing" habilitado em `core` falha no `plan` com um erro do provedor
`terraform_remote_state`, não com um erro óbvio de "permissão negada" — ver
"Configurando os workspaces HCP Terraform" acima.

**4. `vault_namespace` exige licença Vault Enterprise.** Sem ela, `core`
falha ao tentar criar os namespaces. Para uma instalação sem Enterprise, o
módulo `vault/` (isolamento por mount path + policy, sem namespaces) é o
desenho apropriado — não este.
