# ---------------------------------------------------------------------------
# Terraform / provider configuration
#
# Authentication is intentionally NOT declared here. The provider picks the
# token up from the environment:
#
#   export VAULT_ADDR="https://vault.example.com"
#   export VAULT_TOKEN="$(vault print token)"   # or any equivalent mechanism
#
# Never place a Vault token (root or otherwise) in a .tf or .tfvars file:
# it would be committed to git and persisted in the Terraform state.
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

  # Vault Enterprise only; null for OSS.
  namespace = var.vault_namespace
}
