# Inventário de entidades

Cada linha corresponde a um namespace Vault, um workspace HCP Terraform e um
diretório `entities/<nome>/` com state próprio. Ver
[`docs/adr/0001-state-segmentado-por-entidade-de-negocio.md`](../adr/0001-state-segmentado-por-entidade-de-negocio.md)
para o porquê da segmentação, e
[`../../README.md`](../../README.md) para como operar cada uma.

| Entidade | Namespace | Workspace HCP Terraform | Dono | Mount(s) KV | GitHub Teams |
|---|---|---|---|---|---|
| `apps` | `apps` | `vault-yepa-apps` | times de aplicação | `apps` | `developers`, `sre` |
| `platform` | `platform` | `vault-yepa-platform` | platform engineering | `platform` | `platform-engineering` |

`apps` e `platform` são as duas entidades de exemplo, herdadas do desenho do
módulo `vault/` original — ver ADR 0001. Substitua pelos times/produtos
reais da organização ao adotar isto em produção; renomear ou adicionar uma
linha aqui é o primeiro passo de "Como adicionar uma entidade" no README.
