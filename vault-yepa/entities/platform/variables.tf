# ---------------------------------------------------------------------------
# Input variables — structural only, same rule as every other component.
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

# --- GitHub authentication ---------------------------------------------------

variable "github_organization" {
  description = "GitHub organisation whose members and teams may authenticate into the \"platform\" namespace."
  type        = string

  validation {
    condition     = length(trimspace(var.github_organization)) > 0
    error_message = "github_organization must not be empty."
  }
}

variable "github_organization_id" {
  description = "Numeric GitHub organisation ID. Optional but recommended — see modules/vault-entity/variables.tf."
  type        = number
  default     = null
}

variable "github_auth_path" {
  description = "Mount path of the GitHub auth method, inside the \"platform\" namespace."
  type        = string
  default     = "github"
}

variable "github_auth_base_url" {
  description = "GitHub API base URL. Set only for GitHub Enterprise Server."
  type        = string
  default     = null
}

variable "github_auth_default_lease_ttl" {
  description = "Default TTL of tokens issued by the GitHub auth method."
  type        = string
  default     = "1h"
}

variable "github_auth_max_lease_ttl" {
  description = "Maximum TTL a GitHub-issued token can be renewed up to."
  type        = string
  default     = "8h"
}

variable "github_auth_listing_visibility" {
  description = "Whether the GitHub method is listed on the unauthenticated Vault UI login screen (\"unauth\" or \"hidden\")."
  type        = string
  default     = "unauth"

  validation {
    condition     = contains(["unauth", "hidden"], var.github_auth_listing_visibility)
    error_message = "github_auth_listing_visibility must be either \"unauth\" or \"hidden\"."
  }
}

# --- KV v2 secret engine ------------------------------------------------------

variable "kv_mount_path" {
  description = "Mount path of the KV v2 engine holding platform secrets, inside the \"platform\" namespace."
  type        = string
  default     = "platform"
}

variable "kv_max_versions" {
  description = "Number of versions kept per secret before the oldest is pruned."
  type        = number
  default     = 10

  validation {
    condition     = var.kv_max_versions > 0
    error_message = "kv_max_versions must be greater than 0."
  }
}

variable "kv_cas_required" {
  description = "Require Check-And-Set on every write. See vault-yepa/README.md."
  type        = bool
  default     = true
}

variable "kv_delete_version_after" {
  description = "Seconds after which a KV version is auto-deleted. 0 disables it — see docs/adr/."
  type        = number
  default     = 0

  validation {
    condition     = var.kv_delete_version_after >= 0
    error_message = "kv_delete_version_after must be 0 (disabled) or a positive number of seconds."
  }
}
