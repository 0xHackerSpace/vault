# See core/backend.tf for why organization/workspaces.name must be literal
# strings here. Replace "yepa" with your real HCP Terraform organization.

terraform {
  cloud {
    organization = "yepa" # TODO: replace with your HCP Terraform organization

    workspaces {
      name = "vault-yepa-apps"
    }
  }
}
