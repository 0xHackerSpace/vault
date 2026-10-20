# ---------------------------------------------------------------------------
# The "platform" entity: platform-owned secrets (shared infrastructure,
# tooling, glue) — not application secrets, which live in the "apps" mount
# owned entirely by entities/apps/'s own state.
#
# Runs against the SAME flat Vault as entities/apps/. See main.tf there and
# docs/adr/0001 for what that means for isolation, and why
# var.github_auth_path defaults to "github-platform" here, not "github".
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
