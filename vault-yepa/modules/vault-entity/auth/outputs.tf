output "path" {
  description = "Mount path of the GitHub auth method."
  value       = vault_github_auth_backend.this.path
}

output "accessor" {
  description = "Accessor of the GitHub auth method. Useful when writing identity or templated policies. Not a credential."
  value       = vault_github_auth_backend.this.accessor
}

output "organization" {
  description = "GitHub organisation bound to the auth method."
  value       = vault_github_auth_backend.this.organization
}

output "team_policies" {
  description = "Effective GitHub team slug => Vault policy names mapping."
  value       = { for slug, team in vault_github_team.this : slug => team.policies }
}
