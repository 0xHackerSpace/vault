# ---------------------------------------------------------------------------
# Authentication methods
#
# ./auth is a Terraform child module rather than a loose folder of .tf files:
# Terraform only loads .tf files from the root module directory and does not
# recurse into subdirectories, so a plain ./auth/github.tf would never be
# evaluated. Making it a module keeps the requested directory layout while
# actually running, and gives each future auth method (jwt, oidc, approle)
# its own boundary with explicit inputs and outputs.
# ---------------------------------------------------------------------------

module "github_auth" {
  source = "./auth"

  path               = var.github_auth_path
  organization       = var.github_organization
  organization_id    = var.github_organization_id
  base_url           = var.github_auth_base_url
  default_lease_ttl  = var.github_auth_default_lease_ttl
  max_lease_ttl      = var.github_auth_max_lease_ttl
  listing_visibility = var.github_auth_listing_visibility

  # Policy names come from the vault_policy resources, so Terraform creates
  # the policies before mapping any team to them.
  team_policies = local.github_team_policies
}
