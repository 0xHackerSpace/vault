# ---------------------------------------------------------------------------
# The "platform" entity: platform-owned secrets (shared infrastructure,
# tooling, glue) — not application secrets, which live in the isolated
# "apps" namespace/state instead.
#
# Namespace isolation is a deliberate change from the single-tenant vault/
# module this repository also has: there, "platform-engineering" could read
# every application team's secrets for support. Here, that cross-namespace
# grant does not exist, because there is no single shared mount to grant it
# on anymore — see docs/adr/0001 for the trade-off and how to reintroduce
# scoped cross-namespace access deliberately, if it is ever needed.
# ---------------------------------------------------------------------------

module "this" {
  source = "../../modules/vault-entity"

  github_organization            = var.github_organization
  github_organization_id         = var.github_organization_id
  github_auth_path               = var.github_auth_path
  github_auth_base_url           = var.github_auth_base_url
  github_auth_default_lease_ttl  = var.github_auth_default_lease_ttl
  github_auth_max_lease_ttl      = var.github_auth_max_lease_ttl
  github_auth_listing_visibility = var.github_auth_listing_visibility

  kv_mounts = {
    platform = {
      path                 = var.kv_mount_path
      description          = "Platform-owned secrets (shared infrastructure, tooling, glue)."
      max_versions         = var.kv_max_versions
      cas_required         = var.kv_cas_required
      delete_version_after = var.kv_delete_version_after
    }
  }

  github_team_policies = {
    "platform-engineering" = ["platform-admins"]
  }
}
