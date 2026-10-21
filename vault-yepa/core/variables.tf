# ---------------------------------------------------------------------------
# Input variables
#
# Same rule as every other component here: structural inputs only. No
# credential or secret value is ever declared as a Terraform variable.
# ---------------------------------------------------------------------------

variable "vault_address" {
  description = <<-EOT
    Base URL of the Vault cluster, e.g. "https://vault.example.com".
    Leave null to let the provider read VAULT_ADDR from the environment.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.vault_address == null || can(regex("^https?://", var.vault_address))
    error_message = "vault_address must be a full URL starting with http:// or https://."
  }
}

variable "entities" {
  description = <<-EOT
    Business entities that get their own Vault Enterprise namespace and their
    own segmented Terraform state under entities/<name>/. Adding an entity
    here is step 1 of onboarding one — see "Como adicionar uma entidade" in
    vault-yepa/README.md for the rest.
  EOT
  type        = list(string)
  default     = ["apps", "platform"]

  validation {
    condition     = length(var.entities) == length(toset(var.entities))
    error_message = "entities must not contain duplicates."
  }
}
