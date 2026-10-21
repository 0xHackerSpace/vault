# ---------------------------------------------------------------------------
# Input variables
#
# Rule of thumb enforced here: this module takes *structural* inputs only
# (addresses, paths, TTLs, org names). It never takes a credential or a secret
# value, because every input ends up in the Terraform state.
# ---------------------------------------------------------------------------

# --- Connection ------------------------------------------------------------

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

variable "vault_namespace" {
  description = "Vault Enterprise namespace to operate in. Null on Vault OSS."
  type        = string
  default     = null
}

# --- GitHub authentication -------------------------------------------------

variable "github_organization" {
  description = "GitHub organisation whose members and teams are allowed to log in to Vault."
  type        = string

  validation {
    condition     = length(trimspace(var.github_organization)) > 0
    error_message = "github_organization must not be empty."
  }
}

variable "github_organization_id" {
  description = <<-EOT
    Numeric ID of the GitHub organisation. Optional but recommended: pinning
    the ID means a renamed or impersonating organisation cannot satisfy the
    auth method. Vault resolves it automatically when left null.
    Retrieve it with: gh api orgs/<org> --jq .id
  EOT
  type        = number
  default     = null
}

variable "github_auth_path" {
  description = "Mount path of the GitHub auth method."
  type        = string
  default     = "github"
}

variable "github_auth_base_url" {
  description = "GitHub API base URL. Set only for GitHub Enterprise Server, e.g. \"https://github.example.com/api/v3/\"."
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

# --- KV v2 secret engines --------------------------------------------------

variable "kv_mount_path" {
  description = "Mount path of the KV v2 engine holding application secrets."
  type        = string
  default     = "apps"
}

variable "platform_kv_mount_path" {
  description = "Mount path of the KV v2 engine holding platform-owned secrets."
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
  description = <<-EOT
    Require Check-And-Set on every write. Prevents blind overwrites and lost
    updates when several pipelines or people write the same secret.
    With this enabled, `vault kv put` must carry -cas=<current version>.
  EOT
  type        = bool
  default     = true
}

variable "kv_delete_version_after" {
  description = <<-EOT
    Seconds after which a *version* is automatically deleted. 0 disables it.
    Kept at 0 on purpose — see "Decisions" in README.md: automatic expiry of
    secret versions silently removes rollback material and turns a retention
    policy into a data-loss mechanism.
  EOT
  type        = number
  default     = 0

  validation {
    condition     = var.kv_delete_version_after >= 0
    error_message = "kv_delete_version_after must be 0 (disabled) or a positive number of seconds."
  }
}
