# ===========================================================================
# Policy: production-read
# Namespace: apps
#
# A small, reusable capability: read-only access to PRODUCTION application
# secrets. Not tied to a job title, so it can be attached to any team with a
# justified need (today: sre) without duplicating path rules or inventing a
# per-person policy.
#
# Read-only by construction: no create/update/delete/destroy anywhere.
# ===========================================================================

# --- Discovery -------------------------------------------------------------

path "${mount_paths.apps}/metadata" {
  capabilities = ["list"]
}

path "${mount_paths.apps}/metadata/+" {
  capabilities = ["list"]
}

# --- prod ------------------------------------------------------------------

path "${mount_paths.apps}/data/+/prod/*" {
  capabilities = ["read"]
}

path "${mount_paths.apps}/metadata/+/prod" {
  capabilities = ["list"]
}

path "${mount_paths.apps}/metadata/+/prod/*" {
  capabilities = ["read", "list"]
}
