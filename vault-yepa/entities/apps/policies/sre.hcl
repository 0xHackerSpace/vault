# ===========================================================================
# Policy: sre
# Namespace: apps
#
# Audience : members of the GitHub team "sre".
# Intent   : operate the estate — see every environment, read what is needed
#            to debug an incident, change nothing in production.
#
# Production READ access is not defined here: it comes from the separate
# "production-read" policy, attached to the same team. Keeping it separate
# means the production grant can be given to (or taken from) another team
# without editing this file.
#
# Note on "no writes to production": Vault's "deny" is path-scoped, not
# capability-scoped — a deny on ${mount_paths.apps}/data/+/prod/* would also
# kill the read granted by production-read, because deny beats every other
# rule. So write access is withheld by *omission* on data/metadata, and
# denied explicitly only on the KV v2 paths that exist purely to destroy
# data (delete/, undelete/, destroy/), which are distinct paths.
# ===========================================================================

# --- Non-production: read and list ----------------------------------------

path "${mount_paths.apps}/metadata" {
  capabilities = ["list"]
}

path "${mount_paths.apps}/metadata/+" {
  capabilities = ["list"]
}

path "${mount_paths.apps}/data/+/dev/*" {
  capabilities = ["read"]
}

path "${mount_paths.apps}/metadata/+/dev" {
  capabilities = ["list"]
}

path "${mount_paths.apps}/metadata/+/dev/*" {
  capabilities = ["read", "list"]
}

path "${mount_paths.apps}/data/+/qa/*" {
  capabilities = ["read"]
}

path "${mount_paths.apps}/metadata/+/qa" {
  capabilities = ["list"]
}

path "${mount_paths.apps}/metadata/+/qa/*" {
  capabilities = ["read", "list"]
}

# --- Production: destructive KV v2 endpoints are hard-denied ---------------
# Distinct API paths from data/ and metadata/, so denying them does not
# interfere with the read access granted by "production-read".

path "${mount_paths.apps}/delete/+/prod/*" {
  capabilities = ["deny"]
}

path "${mount_paths.apps}/undelete/+/prod/*" {
  capabilities = ["deny"]
}

path "${mount_paths.apps}/destroy/+/prod/*" {
  capabilities = ["deny"]
}

# --- Operational visibility -----------------------------------------------
# Enough to answer "what is mounted, how do I authenticate, what is broken"
# during an incident, inside this namespace. All read-only.

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
