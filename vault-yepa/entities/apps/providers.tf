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

  # Scopes every resource in this workspace to the "apps" namespace created
  # by core/. Read from core's state instead of hardcoded, so a namespace
  # rename in core can never silently drift from what this workspace targets
  # — it would instead fail plan with a clear "namespace does not exist".
  namespace = data.terraform_remote_state.core.outputs.namespace_paths["apps"]
}
