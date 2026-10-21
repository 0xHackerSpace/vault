output "vault_namespace" {
  description = "Vault namespace this workspace operates in."
  value       = data.terraform_remote_state.core.outputs.namespace_paths["apps"]
}

output "github_auth_path" {
  description = "Mount path of the GitHub auth method, e.g. \"github\" for `vault login -method=github -namespace=apps`."
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
  description = "Effective GitHub team slug => Vault policy names mapping, scoped to this namespace."
  value       = module.this.github_team_policies
}
