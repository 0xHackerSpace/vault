# ---------------------------------------------------------------------------
# GitHub auth method — HUMAN authentication only.
#
# Flow:
#   1. an engineer creates a GitHub Personal Access Token with read:org;
#   2. `vault login -method=github` sends that PAT to Vault;
#   3. Vault calls the GitHub API with the PAT, confirms the user belongs to
#      var.organization, and reads the teams they belong to;
#   4. Vault issues a Vault token carrying the policies mapped to those teams.
#
# No GitHub credential is stored here. Vault never holds a PAT of its own for
# this method — the user's PAT is presented at login time and used only for
# that call.
#
# This method is NOT for workloads or CI. Pipelines must not carry a
# long-lived PAT; see jwt-github-actions.tf.example for the JWT/OIDC path.
# ---------------------------------------------------------------------------

resource "vault_github_auth_backend" "this" {
  path         = var.path
  organization = var.organization

  # Optional hardening: pin the org by immutable numeric ID.
  organization_id = var.organization_id

  # GitHub Enterprise Server only.
  base_url = var.base_url

  description = "Human authentication via GitHub organisation membership and team mapping."

  tune {
    default_lease_ttl  = var.default_lease_ttl
    max_lease_ttl      = var.max_lease_ttl
    listing_visibility = var.listing_visibility
    token_type         = "default-service"
  }
}

# ---------------------------------------------------------------------------
# GitHub team -> Vault policy mapping.
#
# Group-based, never per user: access is a property of team membership, so
# joining or leaving a team changes access with no Terraform run.
# ---------------------------------------------------------------------------

resource "vault_github_team" "this" {
  for_each = var.team_policies

  backend  = vault_github_auth_backend.this.path
  team     = each.key
  policies = each.value
}
