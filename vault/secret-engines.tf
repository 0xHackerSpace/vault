# ---------------------------------------------------------------------------
# Secret engines
#
# Terraform owns the *engines* (where secrets live, how they are versioned and
# who may reach them). It deliberately does not own the secret *values*:
# anything passed through Terraform is written to the state file in clear
# text, which would turn the state into the most valuable secret in the
# estate. See "Terraform state" in README.md.
#
# There is intentionally no vault_kv_secret_v2 resource in this repository.
# ---------------------------------------------------------------------------

resource "vault_mount" "kv" {
  for_each = local.kv_mounts

  path        = each.value.path
  type        = "kv"
  description = each.value.description

  options = {
    version = "2"
  }
}

# Engine-level configuration of the KV v2 backends (versioning + CAS).
resource "vault_kv_secret_backend_v2" "kv" {
  for_each = local.kv_mounts

  mount        = vault_mount.kv[each.key].path
  max_versions = each.value.max_versions

  # Writers must pass the version they believe is current (-cas=N), so two
  # concurrent writers cannot silently clobber each other.
  cas_required = each.value.cas_required

  # 0 == disabled. Deliberate: see "Decisions" in README.md.
  delete_version_after = each.value.delete_version_after
}

# ---------------------------------------------------------------------------
# Prepared for future expansion — enable one at a time, with its own policies:
#
#   * Database   (vault_database_secret_backend_connection / _role)
#                dynamic, short-lived DB credentials instead of static ones.
#   * PKI        (vault_mount + vault_pki_secret_backend_role)
#                internal certificate issuance for mTLS.
#   * Transit    (vault_mount type = "transit" + vault_transit_secret_backend_key)
#                encryption-as-a-service, so applications never hold key material.
#
# Each one follows the same rule as KV: Terraform declares the engine, the
# roles and the policies. It never declares the credential values.
# ---------------------------------------------------------------------------
