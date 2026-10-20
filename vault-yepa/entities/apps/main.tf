# ---------------------------------------------------------------------------
# The "apps" entity: application secrets, owned by the application teams.
#
# Everything specific to this entity is DATA here — the mount definition and
# the team -> policy mapping — so onboarding a new app team's access is a
# one-line change, not a new resource. Policy content itself lives in
# ./policies/*.hcl, discovered automatically (see modules/vault-entity).
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
    apps = {
      path                 = var.kv_mount_path
      description          = "Application secrets, owned by the application teams (managed structurally by Terraform)."
      max_versions         = var.kv_max_versions
      cas_required         = var.kv_cas_required
      delete_version_after = var.kv_delete_version_after
    }
  }

  # Keys are GitHub team slugs; values are policy NAMES from ./policies/*.hcl.
  github_team_policies = {
    "developers" = ["developers"]
    "sre"        = ["sre", "production-read"]
  }
}
