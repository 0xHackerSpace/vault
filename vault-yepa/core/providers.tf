# ---------------------------------------------------------------------------
# Terraform / provider configuration
#
# Authentication is intentionally NOT declared here. The provider picks the
# token up from the environment:
#
#   export VAULT_ADDR="https://vault.example.com"
#   export VAULT_TOKEN="$(vault print token)"   # or any equivalent mechanism
#
# In HCP Terraform, set VAULT_ADDR / VAULT_TOKEN as environment variables on
# the vault-yepa-core workspace (marked sensitive), never as Terraform
# variables: any Terraform variable ends up in the state.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
  }
}

provider "vault" {
  # Falls back to VAULT_ADDR when var.vault_address is null.
  address = var.vault_address

  # No `namespace` here, deliberately: this workspace authenticates against
  # the Vault ROOT namespace, because vault_namespace can only be created
  # from the namespace that will be its parent.
}
