# ---------------------------------------------------------------------------
# Vault Enterprise namespaces — one per business entity.
#
# Each namespace becomes a fully isolated tenant: its own auth methods, KV
# mounts and policies, provisioned independently and with independent state
# by entities/<name>/ (see modules/vault-entity). This is the only resource
# this workspace manages, on purpose — see docs/adr/0001 for why the split
# stops here and does not also try to own anything entity-specific.
# ---------------------------------------------------------------------------

resource "vault_namespace" "this" {
  for_each = toset(var.entities)

  path = each.value
}
