# ===========================================================================
# Policy: platform-engineering
#
# Audience : members of the GitHub team "platform-engineering".
# Intent   : own the platform mount end-to-end, and read (never write)
#            application secrets in every environment for support purposes.
#
# This is explicitly NOT an admin policy. The authorisation model itself —
# auth methods, mounts, policies, team mappings — is changed through this
# Terraform repository and code review, not through a human token. Anything
# a person can do here, they can do without being able to grant themselves
# more.
# ===========================================================================

# --- Platform mount: full ownership ---------------------------------------

path "${platform_mount_path}/data/*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list"]
}

path "${platform_mount_path}/metadata" {
  capabilities = ["list"]
}

path "${platform_mount_path}/metadata/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "${platform_mount_path}/delete/*" {
  capabilities = ["update"]
}

path "${platform_mount_path}/undelete/*" {
  capabilities = ["update"]
}

path "${platform_mount_path}/destroy/*" {
  capabilities = ["update"]
}

# --- Application secrets: read-only, every environment --------------------
# Support and debugging. Application teams own the values; platform does not
# write them.

path "${kv_mount_path}/data/*" {
  capabilities = ["read"]
}

path "${kv_mount_path}/metadata" {
  capabilities = ["list"]
}

path "${kv_mount_path}/metadata/*" {
  capabilities = ["read", "list"]
}

# --- Read-only view of the configuration ----------------------------------
# Enough to inspect and audit what Terraform has built, not to change it.

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

# --- Explicit guard rails --------------------------------------------------
# "deny" wins over every grant in every other policy attached to the same
# token, so these hold even if this team is later given additional policies.

# Raw storage access bypasses the barrier entirely.
path "sys/raw/*" {
  capabilities = ["deny"]
}

# Unsealing, rekeying and root generation are break-glass procedures with
# their own out-of-band process.
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
