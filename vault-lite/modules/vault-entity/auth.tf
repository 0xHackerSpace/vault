# ---------------------------------------------------------------------------
# Authentication methods
#
# ./auth is a child module for the same reason as in vault/: Terraform does
# not recurse into subdirectories for .tf files, so a loose ./auth/github.tf
# would never be evaluated. It also gives each future auth method (jwt,
# oidc, approle) its own boundary with explicit inputs and outputs.
#
# No namespace is set here or anywhere in this module: the root module that
# instantiates this module (entities/<name>/) configures the Vault provider
# with namespace = <that entity's namespace>, and every resource declared in
# this module tree inherits it automatically.
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

  team_policies = local.github_team_policies
}
