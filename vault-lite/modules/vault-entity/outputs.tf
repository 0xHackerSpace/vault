# ---------------------------------------------------------------------------
# Outputs
#
# Structural information only. No tokens, no secret values, no accessors
# that could act as credentials.
# ---------------------------------------------------------------------------

output "github_auth_path" {
  description = "Mount path of the GitHub auth method inside this namespace."
  value       = module.github_auth.path
}

output "kv_mount_paths" {
  description = "KV v2 mounts owned by this entity, keyed by logical name."
  value       = { for name, mount in vault_mount.kv : name => mount.path }
}

output "policy_names" {
  description = "Vault policies managed by this entity."
  value       = sort([for policy in vault_policy.this : policy.name])
}

output "github_team_policies" {
  description = "Effective GitHub team slug => Vault policy names mapping, scoped to this namespace."
  value       = module.github_auth.team_policies
}
