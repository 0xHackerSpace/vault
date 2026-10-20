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
# the vault-lite-apps workspace (marked sensitive), never as Terraform
# variables.
#
# No `namespace` attribute here: this is Vault OSS (or Enterprise used
# without namespaces) — a single flat Vault, the same one every other
# entity in vault-lite/ also targets. See docs/adr/0001.
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
  address = var.vault_address
}
