variable "path" {
  description = "Mount path of the GitHub auth method."
  type        = string
  default     = "github"
}

variable "organization" {
  description = "GitHub organisation whose members may authenticate."
  type        = string
}

variable "organization_id" {
  description = "Numeric GitHub organisation ID. Pins the organisation so a rename or an impersonating org cannot satisfy the method. Null lets Vault resolve it."
  type        = number
  default     = null
}

variable "base_url" {
  description = "GitHub API base URL. Set only for GitHub Enterprise Server."
  type        = string
  default     = null
}

variable "default_lease_ttl" {
  description = "Default TTL of tokens issued by this auth method."
  type        = string
  default     = "1h"
}

variable "max_lease_ttl" {
  description = "Maximum TTL a token issued by this auth method can be renewed up to."
  type        = string
  default     = "8h"
}

variable "listing_visibility" {
  description = "Whether the method is advertised on the unauthenticated UI login screen (\"unauth\" or \"hidden\")."
  type        = string
  default     = "unauth"
}

variable "team_policies" {
  description = <<-EOT
    Map of GitHub team slug => list of Vault policy names to attach to members
    of that team. Slugs are the lowercase, hyphenated form found in the team
    URL: github.com/orgs/<org>/teams/<slug>.
  EOT
  type        = map(list(string))
  default     = {}
}
