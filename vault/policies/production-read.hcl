# ===========================================================================
# Policy: production-read
#
# A small, reusable capability: read-only access to PRODUCTION application
# secrets. It is deliberately not tied to a job title, so it can be attached
# to any team that has a justified need (today: sre) without duplicating the
# path rules or inventing a per-person policy.
#
# Read-only by construction: no create/update/delete/destroy anywhere.
# ===========================================================================

# --- Discovery -------------------------------------------------------------

path "${kv_mount_path}/metadata" {
  capabilities = ["list"]
}

path "${kv_mount_path}/metadata/+" {
  capabilities = ["list"]
}

# --- prod ------------------------------------------------------------------

path "${kv_mount_path}/data/+/prod/*" {
  capabilities = ["read"]
}

path "${kv_mount_path}/metadata/+/prod" {
  capabilities = ["list"]
}

path "${kv_mount_path}/metadata/+/prod/*" {
  capabilities = ["read", "list"]
}
