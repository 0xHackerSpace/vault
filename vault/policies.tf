# ---------------------------------------------------------------------------
# Vault policies
#
# Policies live as plain HCL files under ./policies so they can be read,
# reviewed and diffed as policies rather than as Terraform strings.
#
# They are rendered with templatefile() instead of file() for one reason: the
# mount paths are variables, and a policy that hardcodes "apps/" silently
# stops matching the moment var.kv_mount_path changes. The templates use
# ${kv_mount_path} / ${platform_mount_path}; the files stay valid HCL, so
# editors and `vault policy fmt` still understand them.
#
# To add a policy: drop a new <name>.hcl file in ./policies. It is picked up
# automatically and created as a Vault policy called <name>.
# ---------------------------------------------------------------------------

resource "vault_policy" "this" {
  for_each = local.policy_names

  name   = each.value
  policy = templatefile("${path.module}/policies/${each.value}.hcl", local.policy_template_vars)

  # A policy that grants paths on a mount that does not exist yet is legal in
  # Vault but useless; make the ordering explicit.
  depends_on = [vault_mount.kv]
}
