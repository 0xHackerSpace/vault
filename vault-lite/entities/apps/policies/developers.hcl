# ===========================================================================
# Policy: developers
# Entity: apps (flat Vault — no namespace, see docs/adr/0001)
#
# Audience : members of the GitHub team "developers".
# Intent   : read application secrets in NON-PRODUCTION environments only.
#
# Explicitly NOT granted:
#   * any access to prod (neither data nor metadata);
#   * any write, delete, undelete or destroy capability anywhere;
#   * sys/* (so `vault secrets list` will be denied — expected).
#
# KV v2 reminder: the logical path <mount>/<app>/dev/<secret> is served as
# ${mount_paths.apps}/data/<app>/dev/<secret> for values and
# ${mount_paths.apps}/metadata/<app>/dev/<secret> for versions and listing.
# "+" matches exactly one path segment, which is what pins the environment.
# ===========================================================================

# --- Discovery -------------------------------------------------------------
# Needed so `vault kv list` works at all. Exposes application and
# environment *names*, never values.

path "${mount_paths.apps}/metadata" {
  capabilities = ["list"]
}

path "${mount_paths.apps}/metadata/+" {
  capabilities = ["list"]
}

# --- dev -------------------------------------------------------------------

path "${mount_paths.apps}/data/+/dev/*" {
  capabilities = ["read"]
}

path "${mount_paths.apps}/metadata/+/dev" {
  capabilities = ["list"]
}

path "${mount_paths.apps}/metadata/+/dev/*" {
  capabilities = ["read", "list"]
}

# --- qa --------------------------------------------------------------------

path "${mount_paths.apps}/data/+/qa/*" {
  capabilities = ["read"]
}

path "${mount_paths.apps}/metadata/+/qa" {
  capabilities = ["list"]
}

path "${mount_paths.apps}/metadata/+/qa/*" {
  capabilities = ["read", "list"]
}
