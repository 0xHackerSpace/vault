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

  # Same flat Vault as entities/apps/ — no namespace attribute. See
  # entities/apps/providers.tf and docs/adr/0001.
}
