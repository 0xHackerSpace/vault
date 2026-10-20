output "github_auth_path" {
  description = "Mount path of the GitHub auth method, e.g. for `vault login -method=github -path=github-apps`."
  value       = module.this.github_auth_path
}

output "kv_mount_paths" {
  description = "KV v2 mounts owned by this entity, keyed by logical name."
  value       = module.this.kv_mount_paths
}

output "policy_names" {
  description = "Vault policies managed by this entity."
  value       = module.this.policy_names
}

output "github_team_policies" {
  description = "Effective GitHub team slug => Vault policy names mapping."
  value       = module.this.github_team_policies
}
