# ---------------------------------------------------------------------------
# Outputs
#
# Structural information only. No tokens, no secret values, no accessors that
# could act as credentials — outputs are stored in the Terraform state and are
# routinely piped into other tooling.
# ---------------------------------------------------------------------------

output "vault_address" {
  description = "Vault address this configuration targets (null when taken from VAULT_ADDR)."
  value       = var.vault_address
}

output "github_auth_path" {
  description = "Mount path of the GitHub auth method, e.g. \"github\" for `vault login -method=github`."
  value       = module.github_auth.path
}

output "github_organization" {
  description = "GitHub organisation allowed to authenticate."
  value       = module.github_auth.organization
}

output "kv_mount_path" {
  description = "Mount path of the KV v2 engine holding application secrets."
  value       = vault_mount.kv["apps"].path
}

output "kv_mount_paths" {
  description = "All KV v2 mounts managed here, keyed by logical name."
  value       = { for name, mount in vault_mount.kv : name => mount.path }
}

output "policy_names" {
  description = "Vault policies managed by this configuration."
  value       = sort([for policy in vault_policy.this : policy.name])
}

output "github_team_policies" {
  description = "Effective GitHub team slug => Vault policy names mapping."
  value       = module.github_auth.team_policies
}
