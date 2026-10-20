# ===========================================================================
# Policy: platform-admins
# Namespace: platform
#
# Audience : members of the GitHub team "platform-engineering".
# Intent   : own the platform mount end-to-end, inside the platform
#            namespace.
#
# This is explicitly NOT an admin policy. The authorisation model itself —
# auth methods, mounts, policies, team mappings, namespaces — is changed
# through this Terraform repository and code review, not through a human
# token. Anything a person can do here, they can do without being able to
# grant themselves more.
#
# Unlike the single-tenant "platform-engineering" policy in vault/, this
# policy does NOT read application secrets: namespace isolation means the
# "apps" mount is not reachable from this namespace at all. See
# docs/adr/0001 if cross-namespace support access is ever needed.
# ===========================================================================

# --- Platform mount: full ownership ---------------------------------------

path "${mount_paths.platform}/data/*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list"]
}

path "${mount_paths.platform}/metadata" {
  capabilities = ["list"]
}

path "${mount_paths.platform}/metadata/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "${mount_paths.platform}/delete/*" {
  capabilities = ["update"]
}

path "${mount_paths.platform}/undelete/*" {
  capabilities = ["update"]
}

path "${mount_paths.platform}/destroy/*" {
  capabilities = ["update"]
}

# --- Read-only view of the namespace's own configuration -------------------
# Enough to inspect and audit what Terraform has built here, not to change
# it, and not to see into any other namespace.

path "sys/mounts" {
  capabilities = ["read", "list"]
}

path "sys/mounts/*" {
  capabilities = ["read"]
}

path "sys/auth" {
  capabilities = ["read", "list"]
}

path "sys/auth/*" {
  capabilities = ["read"]
}

path "sys/policies/acl" {
  capabilities = ["list"]
}

path "sys/policies/acl/*" {
  capabilities = ["read"]
}

path "sys/health" {
  capabilities = ["read"]
}

path "sys/leases/lookup" {
  capabilities = ["read", "list"]
}

# --- Explicit guard rails ---------------------------------------------------
# "deny" wins over every grant in every other policy attached to the same
# token, so these hold even if this team is later given additional policies.

# Raw storage access bypasses the barrier entirely.
path "sys/raw/*" {
  capabilities = ["deny"]
}

# Unsealing, rekeying and root generation are break-glass procedures with
# their own out-of-band process, and are root-namespace operations anyway.
path "sys/rekey/*" {
  capabilities = ["deny"]
}

path "sys/generate-root/*" {
  capabilities = ["deny"]
}

# Orphan tokens outlive the session that created them and cannot be revoked
# by revoking the parent.
path "auth/token/create-orphan" {
  capabilities = ["deny"]
}
