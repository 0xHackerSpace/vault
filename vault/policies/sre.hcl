# ===========================================================================
# Policy: sre
#
# Audience : members of the GitHub team "sre".
# Intent   : operate the estate — see every environment, read what is needed
#            to debug an incident, change nothing in production.
#
# Production READ access is not defined here: it comes from the separate
# "production-read" policy, which is attached to the same team. Keeping it
# separate means the production grant can be given to (or taken from) another
# team without editing this file.
#
# Note on "no writes to production": Vault's "deny" is path-scoped, not
# capability-scoped — a deny on ${kv_mount_path}/data/+/prod/* would also kill
# the read granted by production-read, because deny beats every other rule.
# So write access is withheld by *omission* on data/metadata, and denied
# explicitly only on the KV v2 paths that exist purely to destroy data.
# ===========================================================================

# --- Non-production: read and list ----------------------------------------

path "${kv_mount_path}/metadata" {
  capabilities = ["list"]
}

path "${kv_mount_path}/metadata/+" {
  capabilities = ["list"]
}

path "${kv_mount_path}/data/+/dev/*" {
  capabilities = ["read"]
}

path "${kv_mount_path}/metadata/+/dev" {
  capabilities = ["list"]
}

path "${kv_mount_path}/metadata/+/dev/*" {
  capabilities = ["read", "list"]
}

path "${kv_mount_path}/data/+/qa/*" {
  capabilities = ["read"]
}

path "${kv_mount_path}/metadata/+/qa" {
  capabilities = ["list"]
}

path "${kv_mount_path}/metadata/+/qa/*" {
  capabilities = ["read", "list"]
}

# --- Production: destructive KV v2 endpoints are hard-denied ---------------
# These are distinct API paths from data/ and metadata/, so denying them does
# not interfere with the read access granted by "production-read".

path "${kv_mount_path}/delete/+/prod/*" {
  capabilities = ["deny"]
}

path "${kv_mount_path}/undelete/+/prod/*" {
  capabilities = ["deny"]
}

path "${kv_mount_path}/destroy/+/prod/*" {
  capabilities = ["deny"]
}

# --- Operational visibility -----------------------------------------------
# Enough to answer "what is mounted, how do I authenticate, what is broken"
# during an incident. All read-only.

path "sys/mounts" {
  capabilities = ["read", "list"]
}

path "sys/auth" {
  capabilities = ["read", "list"]
}

path "sys/health" {
  capabilities = ["read"]
}

path "sys/leases/lookup" {
  capabilities = ["read", "list"]
}

# Never grant raw storage access, in any combination of policies.
path "sys/raw/*" {
  capabilities = ["deny"]
}
