# ---------------------------------------------------------------------------
# HCP Terraform (Terraform Cloud) workspace for this component.
#
# The `cloud` block is parsed before any variable is evaluated, so both
# `organization` and `workspaces.name` MUST be literal strings — they cannot
# reference var.* or local.*. Replace "yepa" below with your real HCP
# Terraform organization before the first `terraform init`.
#
# Unlike vault-yepa/, there is no "core" workspace to depend on: this state
# is fully self-contained. See docs/adr/0001 for why.
# ---------------------------------------------------------------------------

terraform {
  cloud {
    organization = "yepa" # TODO: replace with your HCP Terraform organization

    workspaces {
      name = "vault-lite-apps"
    }
  }
}
