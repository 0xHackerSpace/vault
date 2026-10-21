# ===========================================================================
# Policy: platform-admins
# Entity: platform (this is a FLAT Vault — no namespace, see docs/adr/0001)
#
# Audience : members of the GitHub team "platform-engineering".
# Intent   : own the platform mount end-to-end.
#
# This is explicitly NOT an admin policy. The authorisation model itself —
# auth methods, mounts, policies, team mappings — is changed through this
# Terraform repository and code review, not through a human token. Anything
# a person can do here, they can do without being able to grant themselves
# more.
#
# Unlike vault-yepa/'s "platform-admins" (Vault Enterprise, one namespace per
# entity), this policy runs against the SAME flat Vault as the "apps" entity
# — there is no platform-enforced wall between mounts. This policy does not
# grant read on the "apps" mount by OMISSION, same technique as the rest of
# this repository's policies, but that is a promise this file keeps, not one
# the platform enforces. See docs/adr/0001 for the trade-off, and never add a
# path here (or a wildcard) that reaches outside ${mount_paths.platform}.
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

# --- Read-only view of the Vault's configuration ----------------------------
# Enough to inspect and audit what Terraform has built, not to change it.
# sys/mounts and sys/auth are global in a flat Vault: this DOES list every
# entity's mounts and auth methods by path (not their contents) — narrower
# visibility than that requires namespaces, see docs/adr/0001.

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
