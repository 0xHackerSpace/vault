# ===========================================================================
# Policy: developers
#
# Audience : members of the GitHub team "developers".
# Intent   : read application secrets in NON-PRODUCTION environments only.
#
# Explicitly NOT granted:
#   * any access to prod (neither data nor metadata);
#   * any write, delete, undelete or destroy capability anywhere;
#   * the platform mount;
#   * sys/* (so `vault secrets list` will be denied — expected).
#
# KV v2 reminder: the logical path apps/<app>/dev/<secret> is served as
# ${kv_mount_path}/data/<app>/dev/<secret> for values and
# ${kv_mount_path}/metadata/<app>/dev/<secret> for versions and listing.
# "+" matches exactly one path segment, which is what pins the environment.
# ===========================================================================

# --- Discovery -------------------------------------------------------------
# Needed so `vault kv list <mount>/` and `vault kv list <mount>/<app>/` work
# at all. This exposes application and environment *names*, never values.
# Accepted trade-off: without it the engine is unusable without out-of-band
# knowledge of every path.

path "${kv_mount_path}/metadata" {
  capabilities = ["list"]
}

path "${kv_mount_path}/metadata/+" {
  capabilities = ["list"]
}

# --- dev -------------------------------------------------------------------

path "${kv_mount_path}/data/+/dev/*" {
  capabilities = ["read"]
}

path "${kv_mount_path}/metadata/+/dev" {
  capabilities = ["list"]
}

path "${kv_mount_path}/metadata/+/dev/*" {
  capabilities = ["read", "list"]
}

# --- qa --------------------------------------------------------------------

path "${kv_mount_path}/data/+/qa/*" {
  capabilities = ["read"]
}

path "${kv_mount_path}/metadata/+/qa" {
  capabilities = ["list"]
}

path "${kv_mount_path}/metadata/+/qa/*" {
  capabilities = ["read", "list"]
}
