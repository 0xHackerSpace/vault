# ADR 0001: Isolamento por path de mount, sem namespaces, sem cluster dedicado

## Status

Aceito — 2026-09-27.

## Contexto

`vault-yepa/` resolveu "state segmentado por entidade de negócio" usando
namespaces do **Vault Enterprise**: um namespace por entidade, um workspace
HCP Terraform por entidade, e uma camada `core/` para criar os namespaces
(operação que só o namespace-pai pode fazer).

Esse desenho pressupõe um cluster Vault **dedicado**: HA, replicação e a
licença Enterprise que os namespaces exigem. Foi pedido aqui o equivalente
"empresarial" — múltiplas entidades, state segmentado — **sem** esse
compromisso operacional: uma única instância Vault **OSS**, leve, sem
cluster dedicado.

Consideramos primeiro **HCP Vault Secrets** (SaaS serverless da HashiCorp,
sem cluster nenhum pra operar) como a resposta óbvia a "sem vault dedicated".
Descartado: o produto teve *end-of-sale* em 30/06/2025 e **end-of-life em
01/07/2026** — já desligado. O próprio provider Terraform `hashicorp/hcp` já
removeu os resources `hcp_vault_secrets_*` do branch principal, e a
HashiCorp orienta quem usava HCP Vault Secrets a migrar para... HCP Vault
Dedicated ou Vault Community Edition self-hosted. Não sobrou opção
"HashiCorp sem instância" — daí este ADR ficar com Vault OSS de verdade,
só que sem o desenho de cluster dedicado.

## Decisão

**Uma única instância Vault OSS, flat (sem namespaces). Isolamento entre
entidades por convenção de path (mount KV + auth method próprios por
entidade) e por fronteira de Terraform state — não por fronteira de
plataforma.**

```
vault-lite/
├── modules/vault-entity/    idêntico ao de vault-yepa/, sem nenhuma mudança
└── entities/
    ├── apps/                workspace: vault-lite-apps      (state 1 de 2)
    └── platform/             workspace: vault-lite-platform  (state 2 de 2)
```

Sem `core/`. Em Vault OSS, criar um `vault_mount` ou um
`vault_github_auth_backend` não é uma operação privilegiada de um
namespace-pai — qualquer token com permissão em `sys/mounts` e `sys/auth`
pode fazer isso para o path que quiser. Não existe operação estrutural que
precise ficar de fora do state de cada entidade, então não existe motivo
para uma camada compartilhada: **cada entidade cria seu próprio mount KV e
seu próprio auth method GitHub, do zero, dentro do próprio state**, sem ler
nada de nenhum outro workspace.

`modules/vault-entity/` é reaproveitado **sem nenhuma alteração** de
`vault-yepa/`: o módulo nunca dependeu de namespace — isso sempre foi
responsabilidade do provider no root module. Removendo o `namespace` do
`provider "vault"` em `entities/<nome>/providers.tf`, o mesmo módulo passa a
operar direto na raiz de um Vault flat.

**O preço da ausência de `core/`:** nada mais reserva os paths
centralmente. Dois entities poderiam, em teoria, declarar o mesmo
`kv_mount_path` ou `github_auth_path` e colidir na primeira vez que os dois
dessem `apply`. Mitigado por:

1. **Convenção com dono claro**: `docs/spec/entidades.md` é o registro
   único dos paths reservados — igual ao papel que tinha em `vault-yepa/`,
   só que aqui ele é a única fonte de verdade (não há Terraform reforçando).
2. **CI**: `.github/workflows/terraform-vault-lite.yml`, job
   `path-collisions`, falha o PR se dois `entities/*/variables.tf`
   declararem o mesmo default de `kv_mount_path` ou `github_auth_path`.
   Não impede um valor customizado passado fora do default (via
   `terraform.tfvars` ou variável de workspace) de colidir — isso continua
   sendo revisão de código.

## Trade-offs

**Perdido: fronteira de plataforma.** Em `vault-yepa/`, um token emitido no
namespace `apps` *não consegue* alcançar `platform` — isso é garantido pelo
Vault, não pela policy. Aqui, as duas entidades vivem na mesma árvore ACL:
a policy `platform-admins` não conceder leitura em `apps/` é uma promessa
que o ARQUIVO cumpre, não algo que o Vault impõe. Um `path "apps/*"`
esquecido numa policy futura vaza pra fora da entidade sem nenhum aviso do
Vault. Ver a nota em cada `policies/*.hcl` deste diretório.

Também `sys/mounts` e `sys/auth` são globais num Vault flat: a policy `sre`
(em `entities/apps/policies/sre.hcl`) e `platform-admins` conseguem listar
os paths de mount/auth de QUALQUER entidade (não o conteúdo) — em
`vault-yepa/` isso ficava contido dentro do namespace.

**Ganho: nada pra bootstrapar.** Duas entidades, dois states, zero
dependência entre eles — nem a leitura de `core` que `vault-yepa/` precisa
via `terraform_remote_state`. Qualquer entidade nova é só um novo diretório
com paths únicos, sem tocar em nenhum outro state.

**Ganho: infraestrutura mínima de verdade.** Este repositório nunca
provisionou o binário do Vault (ver "Riscos" em `vault/README.md`,
item 8) — isso não muda aqui. O que muda é que a TOPOLOGIA alvo deixa de
exigir licença Enterprise, HA ou réplicas: uma instância Vault OSS pequena
(um container, um processo systemd) já atende.

**Alternativas consideradas:**

- **HCP Vault Secrets.** Descartado — end-of-life, ver Contexto acima.
- **Secrets manager de cloud provider (AWS/GCP/Azure).** Não escolhido
  porque a organização ainda não fixou uma nuvem — ver a conversa que
  originou este ADR. Continua sendo a opção mais forte no dia em que isso
  for decidido: um projeto GCP ou uma conta AWS por entidade dá isolamento
  de PLATAFORMA de volta (o que este ADR abre mão de ter), sem precisar de
  Vault Enterprise. Revisitar quando a nuvem for definida.
- **Manter um `core/` mesmo sem necessidade técnica**, só para reservar
  paths via Terraform (ex.: `core` cria os `vault_mount` vazios,
  `entities/<nome>/` só tunaria o KV neles). Rejeitado: cria acoplamento
  cross-state onde nenhum é estruturalmente necessário, pelo ganho pequeno
  de trocar "CI falha no PR" por "Terraform falha no apply" para o mesmo
  erro de path duplicado.

## Como adicionar uma entidade

Ver "Como adicionar uma entidade" em `vault-lite/README.md`.
