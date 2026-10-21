# Vault — plataforma de secrets e controle de acesso

Configuração declarativa do HashiCorp Vault via Terraform.

O Terraform aqui administra **estrutura e autorização** — auth methods, secret
engines, policies e o mapeamento de GitHub Teams para policies. Ele
deliberadamente **não administra valores de secrets**.

> Os comentários no código estão em inglês (convenção usual em IaC); a
> documentação está em português.

---

## Sumário

- [Arquitetura](#arquitetura)
- [Estrutura de diretórios](#estrutura-de-diretórios)
- [Como a autenticação GitHub funciona](#como-a-autenticação-github-funciona)
- [GitHub Teams viram Vault Policies](#github-teams-viram-vault-policies)
- [Policies](#policies)
- [Secret engines e convenção de paths](#secret-engines-e-convenção-de-paths)
- [Executando o Terraform](#executando-o-terraform)
- [Login e verificação](#login-e-verificação)
- [Como expandir](#como-expandir)
- [Terraform state](#terraform-state)
- [Decisões](#decisões)
- [Riscos e limitações conhecidas](#riscos-e-limitações-conhecidas)
- [Roadmap: GitHub Actions via OIDC](#roadmap-github-actions-via-oidc)
- [Testando localmente](#testando-localmente)

---

## Arquitetura

```
GitHub User
     │
     │  GitHub Personal Access Token (read:org)
     ▼
Vault GitHub Auth  ──── valida organização e lê os GitHub Teams do usuário
     │
     ▼
Vault Policies     ──── developers │ platform-engineering │ sre │ production-read
     │
     ▼
Secret Engines
     ├── KV v2  apps/       (secrets de aplicação)
     ├── KV v2  platform/   (secrets da plataforma)
     ├── future: Database   (credenciais dinâmicas de banco)
     ├── future: PKI        (emissão de certificados internos)
     └── future: Transit    (encryption as a service)
```

Cadeia de autorização, do time até o secret:

```
GitHub Team
     ↓   (slug do time)
Vault GitHub Auth
     ↓   (resource vault_github_team)
Vault Policy
     ↓   (regras de path + capabilities)
KV / Secret Engine
```

Separação fundamental do desenho:

| Identidade | Método de auth | Credencial | Vida útil |
|---|---|---|---|
| **Humanos** | GitHub Auth | PAT do próprio usuário, apresentado no login | token Vault de 1h (máx. 8h) |
| **Workloads / CI** | JWT Auth (OIDC) — *ainda não habilitado* | JWT efêmero emitido pelo GitHub por job | minutos |

Pipelines **não** usam PAT. Ver [Roadmap](#roadmap-github-actions-via-oidc).

---

## Estrutura de diretórios

```
vault/
├── auth/                            # child module: métodos de autenticação
│   ├── github.tf                    #   GitHub auth backend + team mappings
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── jwt-github-actions.tf.example  # placeholder (inativo) para OIDC de CI
├── policies/                        # uma policy por arquivo HCL
│   ├── developers.hcl
│   ├── platform-engineering.hcl
│   ├── production-read.hcl
│   └── sre.hcl
├── auth.tf                          # instancia o módulo ./auth
├── backend.tf                       # backend de state (exemplos comentados)
├── locals.tf                        # mounts, policies e mapeamento de teams
├── outputs.tf
├── policies.tf                      # renderiza ./policies/*.hcl -> vault_policy
├── providers.tf                     # terraform{} + provider "vault"
├── secret-engines.tf                # KV v2 (apps, platform)
├── variables.tf
├── terraform.tfvars.example
└── README.md
```

Fora deste diretório: `.tflint.hcl`, `.gitignore` e
`.github/workflows/terraform.yml` (fmt, validate, tflint, lint de policies e
secret scan) na raiz do repositório.

### Por que `auth/` é um módulo e não uma pasta solta

O Terraform só carrega arquivos `.tf` do diretório do root module — ele **não
percorre subdiretórios**. Um `auth/github.tf` "solto" nunca seria avaliado.
Transformá-lo em child module preserva o layout desejado, funciona de verdade,
e dá a cada método de autenticação futuro (`jwt`, `oidc`, `approle`) uma
fronteira própria com inputs e outputs explícitos.

---

## Como a autenticação GitHub funciona

1. A pessoa cria um **GitHub Personal Access Token** com escopo `read:org`.
2. `vault login -method=github` envia esse PAT para o Vault.
3. O Vault chama a API do GitHub com o PAT, confirma que o usuário pertence à
   organização configurada (`var.github_organization`) e lê os **teams** dele.
4. O Vault emite um token Vault carregando as policies mapeadas para aqueles
   teams.

Pontos importantes:

- **Nenhum PAT existe no Terraform, no código ou no state.** O PAT é do
  usuário, apresentado no momento do login e usado apenas naquela chamada.
- O PAT precisa de `read:org`. Sem esse escopo o Vault não enxerga os teams e
  o usuário recebe apenas a policy `default`.
- Se a organização exige **SAML SSO**, o PAT precisa ser explicitamente
  autorizado para a organização (`Configure SSO` na página do token no GitHub).
  Sem isso a API do GitHub responde 403 e o login falha.
- Para *fine-grained PATs*, é necessário conceder a permissão de leitura de
  members/organization; classic PATs usam `read:org`.
- **O servidor Vault precisa de saída para `api.github.com`** (ou para a API do
  GitHub Enterprise Server, via `var.github_auth_base_url`) — tanto no login
  quanto ao configurar o auth method.

TTL dos tokens emitidos: `default_lease_ttl = "1h"`, `max_lease_ttl = "8h"`
(ajustáveis por variável). Curto o suficiente para limitar o dano de um token
vazado e longo o suficiente para um dia de trabalho com renovação.

---

## GitHub Teams viram Vault Policies

O mapeamento vive em `locals.tf`, em um único mapa:

```hcl
github_team_policies = {
  "developers"           = [vault_policy.this["developers"].name]
  "platform-engineering" = [vault_policy.this["platform-engineering"].name]
  "sre"                  = [vault_policy.this["sre"].name,
                            vault_policy.this["production-read"].name]
}
```

| GitHub Team (slug) | Vault Policies |
|---|---|
| `developers` | `developers` |
| `platform-engineering` | `platform-engineering` |
| `sre` | `sre`, `production-read` |

Detalhes de implementação:

- As chaves são **slugs** de team (minúsculo, com hífen) — exatamente o que
  aparece em `github.com/orgs/<org>/teams/<slug>`.
- Os valores referenciam **atributos dos resources** `vault_policy`, não
  strings soltas. Um typo ou uma policy removida quebra no `plan`, e o
  Terraform garante que a policy exista antes do mapping que a consome.
- O mapa alimenta um `for_each` em `vault_github_team` — adicionar um time é
  adicionar uma entrada.
- **Não há mapeamento por usuário.** Acesso é propriedade da participação no
  time: entrar ou sair do time muda o acesso sem nenhum `terraform apply`.
  `vault_github_user` existe, mas usá-lo transforma o Terraform em um sistema
  de RH — só use se for tecnicamente inevitável, e com data de validade.

---

## Policies

Cada arquivo em `policies/*.hcl` vira uma policy Vault com o nome do arquivo.
A descoberta é feita com `fileset()`, então **criar uma policy = criar um
arquivo** — não existe segundo lugar para manter sincronizado.

Os arquivos são renderizados com `templatefile()` (e não `file()`) porque os
mounts são variáveis: uma policy que escreve `apps/` fixo deixa de funcionar
silenciosamente se `var.kv_mount_path` mudar. Os templates usam
`${kv_mount_path}` e `${platform_mount_path}` e continuam sendo HCL válido.

### Resumo das capabilities

| Policy | dev | qa | prod | `platform/` | `sys/*` |
|---|---|---|---|---|---|
| `developers` | read | read | — | — | — |
| `production-read` | — | — | read | — | — |
| `sre` | read | read | *(via `production-read`)* + deny em delete/destroy | — | leitura operacional |
| `platform-engineering` | read | read | read | CRUD completo | leitura da configuração |

Verificado contra um Vault real (`vault token capabilities`):

```
developers    apps/data/payment-api/dev/database    read
developers    apps/data/payment-api/prod/database   deny
developers    platform/data/ci/artifactory          deny
sre           apps/data/payment-api/prod/database   read
sre           apps/destroy/payment-api/prod/*       deny
platform-eng  platform/data/ci/artifactory          create, delete, list, patch, read, update
platform-eng  sys/raw/*                             deny
```

### Duas sutilezas de ACL que moldaram estas policies

**1. `deny` é por path, não por capability.** No Vault, um bloco `deny` vence
qualquer grant em qualquer outra policy do mesmo token — mas ele nega o *path
inteiro*. Um `deny` em `apps/data/+/prod/*` dentro de `sre.hcl` mataria também
o `read` concedido por `production-read`. Por isso "SRE não escreve em
produção" é expresso por **omissão** em `data/` e `metadata/`, e o `deny`
explícito fica só nos endpoints do KV v2 que existem para destruir dados
(`delete/`, `undelete/`, `destroy/`), que são paths distintos.

**2. KV v2 tem duas superfícies de API.** O path lógico
`apps/payment-api/dev/database` é servido como:

```
apps/data/payment-api/dev/database        # valores
apps/metadata/payment-api/dev/database    # versões, listagem, destruição
```

e ainda `apps/delete/…`, `apps/undelete/…`, `apps/destroy/…`. Policies precisam
casar com esses paths, não com o path lógico. O curinga `+` casa exatamente um
segmento, e é ele que prende o ambiente: `apps/data/+/dev/*` cobre qualquer
aplicação, apenas em `dev`.

---

## Secret engines e convenção de paths

Dois mounts KV v2, declarados em `locals.kv_mounts` e criados via `for_each`:

| Nome lógico | Mount | Dono |
|---|---|---|
| `apps` | `apps/` (`var.kv_mount_path`) | times de aplicação |
| `platform` | `platform/` (`var.platform_kv_mount_path`) | platform engineering |

Convenção de path lógico:

```
<mount>/<aplicação>/<ambiente>/<nome-do-secret>
```

```
apps/payment-api/dev/database
apps/payment-api/qa/database
apps/payment-api/prod/database
apps/customer-api/dev/internal-api
apps/customer-api/prod/internal-api
```

A posição do ambiente **importa**: é ela que o curinga `+` das policies usa
para separar dev/qa de prod. Inverter a ordem (`apps/dev/payment-api/...`)
tornaria impossível dar a um time acesso a uma aplicação em todos os ambientes
sem reescrever todas as policies.

Configuração dos engines (`vault_kv_secret_backend_v2`):

- `max_versions = 10` — histórico suficiente para rollback sem crescer sem fim.
- `cas_required = true` — toda escrita precisa declarar a versão que acredita
  ser a atual. Impede que dois processos sobrescrevam um ao outro em silêncio.
  **Consequência prática:** `vault kv put` sem `-cas` falha com
  `check-and-set parameter required for this call`. Use `-cas=0` para criar e
  `-cas=<versão-atual>` para atualizar.
- `delete_version_after = 0` (desabilitado) — ver [Decisões](#decisões).

---

## Executando o Terraform

Pré-requisitos: Terraform >= 1.5, um token Vault com permissão para gerenciar
`sys/mounts`, `sys/auth` e `sys/policies`, e acesso de rede ao cluster.

```bash
cd vault

export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="$(vault print token)"   # nunca em arquivo, nunca no git

cp terraform.tfvars.example terraform.tfvars   # já está no .gitignore
$EDITOR terraform.tfvars                       # vault_address, github_organization

terraform init
terraform plan
terraform apply
```

Sem `terraform.tfvars`, passe as variáveis na linha de comando:

```bash
terraform plan \
  -var 'vault_address=https://vault.example.com' \
  -var 'github_organization=my-org' \
  -var 'github_organization_id=123456'
```

> `github_organization_id` é opcional, mas recomendado — ver
> [Riscos](#riscos-e-limitações-conhecidas). Obtenha com
> `gh api orgs/<org> --jq .id`.

O token do provider vem **sempre** do ambiente (`VAULT_TOKEN`, `~/.vault-token`
ou um helper de credenciais). Não existe — e não deve existir — uma variável
Terraform para ele: qualquer input do Terraform acaba no state.

---

## Login e verificação

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_AUTH_GITHUB_TOKEN="github_pat_xxxxx"   # PAT com read:org

vault login -method=github
```

Alternativas equivalentes:

```bash
vault login -method=github token="github_pat_xxxxx"   # fica no histórico do shell
vault login -method=github                            # solicita o token interativamente (preferível)
```

Verificando o que você recebeu:

```bash
vault token lookup                 # identidade, TTL e policies do token atual
vault auth list                    # métodos de autenticação habilitados
vault secrets list                 # secret engines (exige leitura em sys/mounts)
vault policy list                  # policies existentes
vault policy read developers       # conteúdo de uma policy

vault token capabilities apps/data/payment-api/dev/database    # o que EU posso fazer aqui
```

`vault token capabilities` é a forma mais rápida de depurar "por que não
consigo ler isso" — ele responde pelo seu token, contra o path real da API.

Acessando o KV v2:

```bash
vault kv list apps/                            # aplicações
vault kv list apps/payment-api/                # ambientes
vault kv get  apps/payment-api/dev/database    # valores
vault kv get -field=password apps/payment-api/dev/database
vault kv metadata get apps/payment-api/dev/database   # versões
```

Teste administrativo de escrita (**apenas** para quem administra o Vault):

```bash
vault kv put -cas=0 apps/example/dev/test value=test
vault kv get  apps/example/dev/test
vault kv metadata delete apps/example/dev/test   # limpeza
```

> O `-cas=0` é obrigatório por causa de `cas_required = true`.
>
> **Developers não conseguem executar esse `put`** — e isso é o comportamento
> desejado. A policy `developers` é somente leitura. Valores de secret são
> escritos por quem os administra, fora do Terraform.

---

## Como expandir

### Adicionar um GitHub Team

1. Se ele precisar de permissões novas, crie a policy (abaixo).
2. Adicione a entrada em `locals.github_team_policies` (`locals.tf`), usando o
   **slug** do time e referenciando os resources de policy:

```hcl
"data-engineering" = [
  vault_policy.this["data-engineering"].name,
]
```

3. `terraform plan && terraform apply`.

### Criar uma policy

1. Crie `policies/<nome>.hcl`. Use `${kv_mount_path}` /
   `${platform_mount_path}` em vez de escrever o mount fixo.
2. Só isso — `fileset()` a descobre e cria `vault_policy.this["<nome>"]`.
3. Anexe-a a um time em `locals.github_team_policies`.

Ao escrever a policy: comece do que a pessoa precisa fazer, não do que o time
"é"; prefira compor policies pequenas e reutilizáveis (como `production-read`)
a duplicar blocos de path; e lembre das duas sutilezas de ACL descritas acima.

### Adicionar um mount KV

Adicione uma entrada em `locals.kv_mounts` (`locals.tf`). Os resources
`vault_mount` e `vault_kv_secret_backend_v2` já iteram sobre o mapa.

### Adicionar um secret engine novo (Database, PKI, Transit)

`secret-engines.tf` tem o esqueleto comentado de cada um. A regra vale para
todos: o Terraform declara o engine, as roles e as policies; ele nunca declara
o valor da credencial. Um engine Database, por exemplo, tem a connection string
gerenciada fora do Terraform (ou via `vault write` a partir de um cofre de
bootstrap), enquanto as roles e policies ficam aqui.

---

## Terraform state

**O state deste módulo é sensível**, mesmo sem conter secrets de aplicação.

Tudo o que passa pelo Terraform — inputs, atributos de resource, outputs — é
gravado em texto claro no state. Aqui isso significa o texto completo de todas
as policies, a organização GitHub, o layout de mounts e a configuração de
autenticação: um mapa completo do modelo de autorização. Trate o state como
confidencial.

É exatamente por esse motivo que **valores de secret não passam pelo
Terraform**. Não há nenhum `vault_kv_secret_v2` neste repositório, e não deve
haver: usá-lo copiaria a senha do banco de produção para dentro do state,
tornando o arquivo de state mais valioso que o próprio Vault.

| Terraform administra | Outro processo administra |
|---|---|
| auth methods | valores de secrets |
| secret engines e mounts | rotação de credenciais |
| policies | conteúdo do KV |
| mapeamento GitHub Team → policy | |
| roles (JWT, Database, PKI) | |
| configuração estrutural | |

Escrita de valores deve ser feita por um caminho auditado — `vault kv put` por
quem administra, um operador rodando dentro do cluster, um pipeline de rotação,
ou o External Secrets Operator lendo do Vault.

Requisitos do backend de state (exemplos comentados em `backend.tf`):
criptografia em repouso, locking, versionamento e acesso restrito.

---

## Decisões

**`delete_version_after = 0` (expiração automática desabilitada).**
A opção apaga *versões* de secret depois de um tempo. Ela parece uma política
de retenção, mas na prática é um mecanismo de perda de dados: remove
silenciosamente o material de rollback e, quando alcança a versão atual,
transforma um secret vivo em um 404 no meio de um incidente. Retenção por
quantidade (`max_versions = 10`) dá o mesmo controle de crescimento sem
depender do relógio. Se algum mount futuro tiver exigência regulatória de
expiração, habilite **naquele mount**, com valor explícito e documentado —
`locals.kv_mounts` já suporta valores por mount.

**`cas_required = true`.** Custa um `-cas=N` em cada escrita e, em troca,
elimina a classe inteira de "dois pipelines escreveram o mesmo secret e um
sumiu". Vale o atrito.

**Policies em arquivos, não em heredoc.** HCL de policy revisado como HCL de
policy: dá diff legível, syntax highlighting e `vault policy fmt`.

**`fileset()` para descobrir policies.** Elimina a lista duplicada entre
`locals.tf` e o diretório. O risco de "criar uma policy sem querer" é baixo
(o arquivo precisa terminar em `.hcl` dentro de `policies/`) e o erro oposto —
policy criada e nunca aplicada, ou aplicada e nunca criada — é mais comum.

**Mount `platform/` criado agora, não depois.** A policy
`platform-engineering` precisa de um mount para conceder; um grant apontando
para mount inexistente é legal no Vault e inútil na prática. Criar os dois
mounts junto mantém policy e realidade em sincronia.

**`production-read` separada de `sre`.** Acesso a produção é uma *capacidade*,
não um cargo. Separada, ela pode ser concedida a outro time (ou revogada de
SRE) mexendo em uma linha de `locals.tf`, sem editar policy nenhuma.

**Sem `plan` contra o Vault real no CI.** Exigiria um token Vault guardado no
GitHub. O CI valida o que dá para validar sem credencial (`fmt`, `validate`,
`tflint`, sintaxe das policies, secret scan). O `plan` autenticado entra quando
o JWT/OIDC estiver no lugar.

---

## Riscos e limitações conhecidas

**1. Vault precisa de saída para a API do GitHub.**
Verificado na prática: sem acesso a `api.github.com`, habilitar o auth method
falha com `unable to fetch the organization_id, you must manually set it in the
config`. Definir `var.github_organization_id` evita essa consulta no momento da
configuração, mas o **login continua exigindo** que o Vault alcance a API do
GitHub. Em rede fechada, libere o egress do Vault (ou um proxy) para
`api.github.com`.

**2. Sem `organization_id`, a organização é resolvida por nome.**
Fixar o ID numérico é uma defesa contra rename da organização e contra uma
organização homônima. Recomendado em produção.

**3. Disponibilidade do Vault passa a depender do GitHub.**
Se o GitHub estiver fora do ar, ninguém faz login via GitHub. Mantenha um
caminho break-glass independente (chaves de unseal e um método de auth
alternativo guardados fora de banda) e trate-o com o mesmo rigor.

**4. PAT é uma credencial de longa duração.**
Enquanto o login humano usar PAT, existe um segredo durável na máquina de cada
pessoa. Mitigações: exigir expiração nos PATs da organização, preferir
fine-grained PATs, manter o TTL do token Vault curto e, no médio prazo, migrar
o login humano para OIDC (SSO) em vez de GitHub PAT.

**5. Listagem revela nomes.**
As policies concedem `list` em `apps/metadata` e `apps/metadata/+` para que
`vault kv list` seja utilizável. Um developer consegue portanto ver que existe
uma pasta `prod/` e quais aplicações existem — nunca o conteúdo. É uma troca
consciente: sem isso, o engine só é navegável com conhecimento prévio de cada
path. Se nomes de aplicação forem considerados sensíveis, remova esses dois
blocos e distribua os paths por outro canal.

**6. `platform-engineering` lê todos os secrets de aplicação, inclusive prod.**
É intencional (suporte e debugging), mas é uma concentração de poder. Mantenha
o time pequeno, com audit device habilitado, e reavalie quando o modelo de
identidade permitir acesso just-in-time.

**7. Audit device não é gerenciado aqui.**
Um audit device é obrigatório em produção e não foi incluído porque o destino
(arquivo, socket, syslog) é específico da infraestrutura. **Habilite um antes
de colocar em produção** — sem ele não há registro de quem leu o quê.

**8. Nada aqui gerencia o bootstrap do Vault.**
Inicialização, unseal, HA, storage e o ciclo de vida do root token estão fora
do escopo deste módulo. O root token deve ser revogado após o bootstrap
(`vault token revoke <root-token>`), e o Terraform deve rodar com um token de
operação de escopo reduzido.

---

## Roadmap: GitHub Actions via OIDC

**GitHub Actions não deve usar PAT.** O padrão preferencial para workloads:

```
GitHub Actions
     ↓  (permissions: id-token: write)
GitHub OIDC JWT      — efêmero, por job, não exportável
     ↓
Vault JWT Auth       — valida a assinatura contra o JWKS do GitHub
     ↓
Vault Role           — bound_claims: repository, ref, environment
     ↓
Vault Policy
     ↓
Secret Engine
```

Por que não PAT: o JWT é emitido por job, expira em minutos, é preso a um
repositório/branch/environment específico e não existe credencial durável para
vazar, rotacionar ou esquecer. Um PAT em CI é uma credencial permanente e com
escopo de pessoa — a antítese de identidade de workload.

O esqueleto está em `auth/jwt-github-actions.tf.example` (inativo — o Terraform
ignora a extensão `.tf.example`). Para adotar:

1. renomeie para `auth/jwt.tf`;
2. adicione as variáveis correspondentes em `auth/variables.tf` e ligue-as no
   root module (`auth.tf`, `variables.tf`);
3. **revise os `bound_claims` antes do apply** — eles são a fronteira de
   segurança inteira. Sem `bound_claims` restritivos, qualquer repositório do
   GitHub consegue assumir a role;
4. crie uma role e uma policy **por workload**, com os paths mínimos
   (`apps/data/<app>/<env>/*`), nunca uma role genérica para a organização;
5. mantenha `token_ttl` na ordem de minutos.

---

## Testando localmente

Toda esta configuração foi validada contra um Vault de desenvolvimento real.
Para reproduzir:

```bash
# 1. Vault em modo dev (dados em memória, some ao parar)
vault server -dev -dev-root-token-id=root &

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

# 2. Aplicar
cd vault
terraform init
terraform apply \
  -var 'vault_address=http://127.0.0.1:8200' \
  -var 'github_organization=acme-test' \
  -var 'github_organization_id=123456'
```

> `github_organization_id` é necessário no ambiente de teste porque a máquina
> local normalmente não tem (ou não deve ter) acesso à API do GitHub.

```bash
# 3. Idempotência — deve reportar "No changes"
terraform plan \
  -var 'vault_address=http://127.0.0.1:8200' \
  -var 'github_organization=acme-test' \
  -var 'github_organization_id=123456'

# 4. Semear secrets de teste (note o -cas=0, por causa de cas_required)
vault kv put -cas=0 apps/payment-api/dev/database  user=devuser
vault kv put -cas=0 apps/payment-api/qa/database   user=qauser
vault kv put -cas=0 apps/payment-api/prod/database user=produser
vault kv put -cas=0 platform/ci/artifactory        token=x

# 5. Verificar as policies com tokens reais
DEV=$(vault token create -policy=developers -field=token)
SRE=$(vault token create -policy=sre -policy=production-read -field=token)
PE=$(vault token create -policy=platform-engineering -field=token)

VAULT_TOKEN=$DEV vault token capabilities apps/data/payment-api/dev/database   # read
VAULT_TOKEN=$DEV vault token capabilities apps/data/payment-api/prod/database  # deny
VAULT_TOKEN=$DEV vault token capabilities platform/data/ci/artifactory         # deny
VAULT_TOKEN=$SRE vault token capabilities apps/data/payment-api/prod/database  # read
VAULT_TOKEN=$SRE vault token capabilities apps/destroy/payment-api/prod/db     # deny
VAULT_TOKEN=$PE  vault token capabilities sys/raw/core                         # deny

VAULT_TOKEN=$DEV vault kv get apps/payment-api/dev/database    # ok
VAULT_TOKEN=$DEV vault kv get apps/payment-api/prod/database   # 403
VAULT_TOKEN=$DEV vault kv put -cas=1 apps/payment-api/dev/database user=x  # 403

# 6. Qualidade
terraform fmt -check -recursive -diff
terraform validate
tflint --config "$(git rev-parse --show-toplevel)/.tflint.hcl" --recursive

# 7. Limpar
terraform destroy \
  -var 'vault_address=http://127.0.0.1:8200' \
  -var 'github_organization=acme-test' \
  -var 'github_organization_id=123456'
kill %1   # encerra o vault -dev
```

O login via GitHub **não** é testável contra o `vault -dev` sem uma organização
GitHub real e acesso à API — é a única parte do fluxo que exige um ambiente de
verdade.
