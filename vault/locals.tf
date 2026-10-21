# ---------------------------------------------------------------------------
# Locals
#
# Everything that is expected to grow over time is modelled as data here, so
# that adding an application environment, a KV mount, a policy or a GitHub
# team is a data change rather than a code change.
# ---------------------------------------------------------------------------

locals {
  # --- KV v2 secret engines -------------------------------------------------
  #
  # Logical secret layout (see README.md):
  #   <mount>/<application>/<environment>/<secret-name>
  #
  # KV v2 rewrites that into two API surfaces, which is what policies match:
  #   <mount>/data/<application>/<environment>/<secret-name>
  #   <mount>/metadata/<application>/<environment>/<secret-name>
  #
  # Add a mount by adding an entry here; the resources fan out with for_each.
  kv_mounts = {
    apps = {
      path                 = var.kv_mount_path
      description          = "Application secrets, owned by the application teams (managed structurally by Terraform)."
      max_versions         = var.kv_max_versions
      cas_required         = var.kv_cas_required
      delete_version_after = var.kv_delete_version_after
    }

    platform = {
      path                 = var.platform_kv_mount_path
      description          = "Platform-owned secrets (shared infrastructure, tooling, glue). Not readable by application developers."
      max_versions         = var.kv_max_versions
      cas_required         = var.kv_cas_required
      delete_version_after = var.kv_delete_version_after
    }
  }

  # --- Policies -------------------------------------------------------------
  #
  # Discovered from the filesystem: one *.hcl file in ./policies == one Vault
  # policy, named after the file. Creating a policy is therefore "add a file",
  # with no second place to keep in sync.
  policy_files = fileset("${path.module}/policies", "*.hcl")

  policy_names = toset([
    for file in local.policy_files : trimsuffix(file, ".hcl")
  ])

  # Values interpolated into the policy templates. Keeps mount paths out of
  # the .hcl files so they follow var.kv_mount_path / var.platform_kv_mount_path.
  policy_template_vars = {
    kv_mount_path       = var.kv_mount_path
    platform_mount_path = var.platform_kv_mount_path
  }

  # --- GitHub team -> Vault policy mapping ----------------------------------
  #
  # Keys are GitHub *team slugs* (lowercase, hyphenated), exactly as they
  # appear in the team URL: github.com/orgs/<org>/teams/<slug>.
  #
  # Mappings are per team, never per user: access follows membership of a
  # team, and offboarding someone from the team removes their access with no
  # Terraform change.
  #
  # Policy names are taken from the vault_policy resources rather than typed
  # as free strings, so a typo or a deleted policy fails at plan time and
  # Terraform orders the policy before the mapping that consumes it.
  github_team_policies = {
    "developers" = [
      vault_policy.this["developers"].name,
    ]

    "platform-engineering" = [
      vault_policy.this["platform-engineering"].name,
    ]

    "sre" = [
      vault_policy.this["sre"].name,
      vault_policy.this["production-read"].name,
    ]
  }
}
