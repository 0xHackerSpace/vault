# ---------------------------------------------------------------------------
# Vault policies
#
# Policies live as plain HCL files under the CALLING root module's policies/
# directory (entities/<name>/policies/*.hcl), not under this shared module,
# so each entity keeps its own set, reviewed and diffed as policies rather
# than as Terraform strings.
#
# Rendered with templatefile() instead of file(): mount paths are variables,
# and a policy that hardcodes a mount path silently stops matching the
# moment that variable changes. Templates use ${mount_paths.<key>}; the
# files stay valid HCL, so editors and `vault policy fmt` still understand
# them.
# ---------------------------------------------------------------------------

resource "vault_policy" "this" {
  for_each = local.policy_names

  name   = each.value
  policy = templatefile("${path.root}/policies/${each.value}.hcl", local.policy_template_vars)

  # A policy that grants paths on a mount that does not exist yet is legal in
  # Vault but useless; make the ordering explicit.
  depends_on = [vault_mount.kv]
}
