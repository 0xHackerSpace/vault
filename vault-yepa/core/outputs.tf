# ---------------------------------------------------------------------------
# Outputs
#
# Consumed cross-workspace by entities/<name>/ via terraform_remote_state
# (see entities/<name>/remote_state.tf). Structural information only.
# ---------------------------------------------------------------------------

output "namespace_paths" {
  description = "Entity name => Vault namespace path."
  value       = { for name, ns in vault_namespace.this : name => ns.path }
}

output "namespace_ids" {
  description = "Entity name => Vault namespace ID. Not a credential."
  value       = { for name, ns in vault_namespace.this : name => ns.namespace_id }
}
