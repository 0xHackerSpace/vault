# Inventário de entidades — registro de paths reservados

**Esta tabela é a fonte de verdade dos paths reservados no Vault flat.**
Sem `core/` reservando nada via Terraform (ver
[`../adr/0001-mount-path-por-entidade-sem-namespaces.md`](../adr/0001-mount-path-por-entidade-sem-namespaces.md)),
é este arquivo — mais o job `path-collisions` do CI — que impede duas
entidades de colidirem no mesmo mount ou no mesmo auth method. Atualize
esta tabela **antes** de abrir o PR que adiciona uma entidade nova.

| Entidade | Workspace HCP Terraform | Mount KV (`kv_mount_path`) | Auth GitHub (`github_auth_path`) | GitHub Teams |
|---|---|---|---|---|
| `apps` | `vault-lite-apps` | `apps` | `github-apps` | `developers`, `sre` |
| `platform` | `vault-lite-platform` | `platform` | `github-platform` | `platform-engineering` |

`apps` e `platform` são as duas entidades de exemplo, herdadas do desenho
de `vault/` e `vault-yepa/`. Substitua pelos times/produtos reais da
organização ao adotar isto em produção.
