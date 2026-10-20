# ---------------------------------------------------------------------------
# The "apps" entity: application secrets, owned by the application teams.
#
# Runs against the SAME flat Vault as entities/platform/ — there is no
# namespace boundary between them (see docs/adr/0001). Isolation here comes
# from two things this state owns end to end and no other state touches:
#   * a KV mount at a path no other entity may also claim (var.kv_mount_path);
#   * a GitHub auth method at a path no other entity may also claim
#     (var.github_auth_path, default "github-apps" — NOT the bare "github"
#     vault-yepa/ used, because that default would collide with
#     entities/platform/ on this shared Vault).
#
# Uniqueness of both paths across entities is checked in CI
# (.github/workflows/terraform-vault-lite.yml, job "path-collisions"), not
# by Terraform — there is no shared state left to enforce it centrally.
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
