# ---------------------------------------------------------------------------
# Secret engines
#
# Terraform owns the *engines* (where secrets live, how they are versioned
# and who may reach them). It deliberately does not own the secret *values*:
# anything passed through Terraform is written to the state file in clear
# text. See "Terraform state" in vault-yepa/README.md.
#
# There is intentionally no vault_kv_secret_v2 resource anywhere in this
# repository.
# ---------------------------------------------------------------------------

resource "vault_mount" "kv" {
  for_each = var.kv_mounts

  path        = each.value.path
  type        = "kv"
  description = each.value.description

  options = {
    version = "2"
  }
}

# Engine-level configuration of the KV v2 backends (versioning + CAS).
resource "vault_kv_secret_backend_v2" "kv" {
  for_each = var.kv_mounts

  mount        = vault_mount.kv[each.key].path
  max_versions = each.value.max_versions

  # Writers must pass the version they believe is current (-cas=N), so two
  # concurrent writers cannot silently clobber each other.
  cas_required = each.value.cas_required

  # 0 == disabled, same rationale as vault/: automatic version expiry
  # silently removes rollback material. See vault-yepa/docs/adr/.
  delete_version_after = each.value.delete_version_after
}
