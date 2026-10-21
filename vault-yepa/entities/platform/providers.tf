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

  # Scopes every resource in this workspace to the "platform" namespace
  # created by core/. See entities/apps/providers.tf for the rationale.
  namespace = data.terraform_remote_state.core.outputs.namespace_paths["platform"]
}
