# ---------------------------------------------------------------------------
# Input variables
#
# Same rule as the rest of this repository: structural inputs only (paths,
# TTLs, org names, mount definitions). Never a credential or a secret value —
# every input ends up in the calling root module's Terraform state.
#
# This module is instantiated once per business entity (see
# entities/<name>/main.tf). It owns everything INSIDE one Vault namespace:
# the GitHub auth method, the KV mounts and the policies. It does not create
# the namespace itself — that is core/'s job, since creating a namespace is a
# root-namespace-only operation and must not depend on any entity's state.
# ---------------------------------------------------------------------------

# --- GitHub authentication ---------------------------------------------------

variable "github_organization" {
  description = "GitHub organisation whose members and teams may authenticate into this namespace."
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
    auth method. Retrieve it with: gh api orgs/<org> --jq .id
  EOT
  type        = number
  default     = null
}

variable "github_auth_path" {
  description = "Mount path of the GitHub auth method, inside this namespace."
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

# --- KV v2 secret engines ----------------------------------------------------

variable "kv_mounts" {
  description = <<-EOT
    KV v2 mounts owned by this entity, keyed by logical name. Most entities
    need exactly one; a second entry is for entities that split secrets into
    more than one mount (e.g. different retention or ownership rules).

    The map key is also the name policy templates use to reach the mount's
    path: a key "apps" is exposed to policies/*.hcl as $${mount_paths.apps}.
  EOT
  type = map(object({
    path                 = string
    description          = optional(string, "")
    max_versions         = optional(number, 10)
    cas_required         = optional(bool, true)
    delete_version_after = optional(number, 0)
  }))
  default = {}
}

# --- GitHub team -> Vault policy mapping -------------------------------------

variable "github_team_policies" {
  description = <<-EOT
    Map of GitHub team slug => list of policy NAMES (matching a file under
    the calling root module's policies/ directory, without the .hcl
    extension). Names are resolved to vault_policy resource attributes
    inside this module rather than used as free strings, so a typo or a
    deleted policy fails at plan time instead of silently granting nothing.
  EOT
  type        = map(list(string))
  default     = {}
}
