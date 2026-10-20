# ADR 0001: State Terraform segmentado por entidade de negócio

## Status

Aceito — 2026-09-18.

## Contexto

O módulo `vault/` existente neste repositório administra todo o Vault (auth
methods, mounts KV, policies, mapeamento de GitHub Teams) como um **único
root module com um único state**. Isso funciona bem para uma instalação
pequena, mas não escala como plataforma multi-tenant:

- **Blast radius.** Um `terraform apply` errado em qualquer parte do state
  (uma policy, um mount, uma variável) pode afetar qualquer time que use o
  Vault, mesmo que a mudança pretendida fosse local a um único time.
- **Lock global.** Terraform trava o state inteiro durante um `apply`. Dois
  times não conseguem fazer mudanças estruturais em paralelo.
- **Permissão binária.** Acesso ao state (e ao token Vault necessário para
  usá-lo) é tudo-ou-nada: não existe "este time só pode mudar suas próprias
  policies".
- **Confidencialidade.** O state inteiro carrega o texto de *todas* as
  policies, de todos os times, mesmo para quem só precisa mexer em uma.

`vault-yepa/` é a segunda instalação neste repositório e existe justamente
para resolver isso: um Vault "empresarial", com state **segmentado por
entidade de negócio**, não um state único.

## Decisão

**Cada entidade de negócio (time/produto) tem seu próprio Vault Enterprise
namespace e seu próprio Terraform root module com state próprio.** Existe
uma camada adicional, mínima e compartilhada, para o que estrutural e
tecnicamente não pode viver dentro de uma entidade.

```
vault-yepa/
├── core/                  workspace: vault-yepa-core     (namespace ROOT)
│   └── cria os vault_namespace — um por entidade
├── modules/vault-entity/  módulo compartilhado (sem state próprio)
│   └── auth GitHub + mounts KV + policies, parametrizado por entidade
└── entities/
    ├── apps/              workspace: vault-yepa-apps     (namespace "apps")
    └── platform/          workspace: vault-yepa-platform (namespace "platform")
```

Três workspaces HCP Terraform, três states independentes:

| Workspace | Namespace Vault | O que administra |
|---|---|---|
| `vault-yepa-core` | root | `vault_namespace` — uma por entidade, nada mais |
| `vault-yepa-apps` | `apps` | auth GitHub, mount(s) KV, policies, GitHub Teams — tudo dentro do namespace `apps` |
| `vault-yepa-platform` | `platform` | idem, dentro do namespace `platform` |

Por que a camada `core` existe, apesar da decisão ser "por entidade":
criar um `vault_namespace` é uma operação que só pode ser feita a partir do
namespace **pai** (o root, no caso de namespaces de primeiro nível) — nenhum
state de entidade pode criar o próprio namespace em que ele mesmo vai operar.
`core` fica deliberadamente pequeno (um único tipo de resource) exatamente
para minimizar o que depende dele: qualquer coisa que puder viver dentro de
uma entidade, vive dentro da entidade.

**Acoplamento entre `core` e `entities/<nome>/`:** cada entidade lê o path do
seu namespace do state de `core` via `terraform_remote_state` (ver
`entities/<nome>/remote_state.tf`), em vez de repetir o nome como uma string
solta. Um namespace renomeado em `core` quebra o `plan` da entidade com um
erro claro, em vez de operar silenciosamente contra o namespace errado.

**Módulo compartilhado, sem state próprio.** `modules/vault-entity/` não é
um workspace — é um child module comum, instanciado uma vez por
`entities/<nome>/`. Ele existe para não duplicar a lógica de "auth GitHub +
mounts KV + policies discovery via `fileset()`" a cada nova entidade; o que
varia por entidade (organização GitHub, mounts, mapeamento de times,
arquivos de policy) é passado como input.

## Trade-offs

**Perdido: leitura cross-tenant.** No módulo `vault/` original, a policy
`platform-engineering` lia os secrets de aplicação de *todos* os times, para
suporte. Com namespaces isolados, isso deixa de existir por padrão — não há
mount compartilhado para conceder. Isso é tratado como aceitável (e até
desejável) neste ADR: isolamento forte é o objetivo declarado de uma
instalação "empresarial" multi-tenant. Se acesso cross-namespace para
suporte for necessário no futuro, ele deve ser um mecanismo deliberado e
auditável — por exemplo, um novo namespace `support` com policies
explicitamente concedidas em cada namespace de entidade — nunca um efeito
colateral do desenho de mounts.

**Ganho: menor acoplamento operacional, mais coordenação manual.** Cada
entidade pode dar `apply` de forma independente, sem lock com as outras. Em
troca, a ordem entre camadas — `core` antes de qualquer `entities/<nome>/` —
não é imposta pelo Terraform (states diferentes não têm `depends_on` entre
si); é uma regra operacional documentada no README, não uma garantia da
ferramenta.

**Alternativas consideradas:**

- **Workspaces nativos do Terraform (`terraform workspace`) num único root
  module.** Rejeitado: workspaces nativos compartilham o mesmo código e o
  mesmo arquivo de backend: mudam apenas variáveis de contexto, não isolam
  permissão de acesso ao state nem permitem dar `apply` em paralelo sem lock
  cruzado real (o backend ainda é um por configuração, mudando de "key"
  lógica). Não resolve o problema de blast radius nem de permissão granular.
- **Um root module por camada técnica (auth / policies / secret-engines),
  não por entidade.** Rejeitado como eixo *primário*: uma mudança na policy
  de um único time ainda obrigaria tocar o mesmo state usado por todos os
  outros times. Fica mais próximo do desenho técnico do módulo `vault/`
  original do que do objetivo "state por entidade de negócio" pedido.
- **Terraform Enterprise/HCP `data "tfe_outputs"` (provider `hashicorp/tfe`)
  em vez de `terraform_remote_state`.** Considerado equivalente e mais
  moderno; não usado agora para manter uma dependência de provider a menos.
  Trocar é uma mudança local a `remote_state.tf` em cada entidade, não uma
  mudança de arquitetura — revisitar se o "remote state sharing" nativo se
  mostrar insuficiente (ex.: necessidade de token com escopo mais estreito
  por workspace consumidor).

## Como adicionar uma entidade

Ver "Como adicionar uma entidade" em `vault-yepa/README.md` — não duplicado
aqui para não ter duas fontes da verdade.
