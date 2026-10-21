# ---------------------------------------------------------------------------
# HCP Terraform (Terraform Cloud) workspace for this component.
#
# The `cloud` block is parsed before any variable is evaluated, so both
# `organization` and `workspaces.name` MUST be literal strings — they cannot
# reference var.* or local.*. Replace "yepa" below with your real HCP
# Terraform organization before the first `terraform init`.
#
# This is the ONLY workspace in vault-yepa/ that operates in the Vault root
# namespace: creating a namespace is a root-namespace-only operation, so it
# cannot live in any entity's state. Every other workspace (entities/<name>/)
# sets its provider's namespace to the one this workspace creates for it, and
# reads which one that is from this workspace's outputs — see
# entities/<name>/remote_state.tf.
# ---------------------------------------------------------------------------

terraform {
  cloud {
    organization = "yepa" # TODO: replace with your HCP Terraform organization

    workspaces {
      name = "vault-yepa-core"
    }
  }
}
