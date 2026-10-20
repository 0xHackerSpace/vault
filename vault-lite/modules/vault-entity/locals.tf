# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------

locals {
  # --- Policies ---------------------------------------------------------
  #
  # Discovered from the CALLING root module's directory, not this module's
  # own directory: path.root always resolves to entities/<name>/, so
  # entities/apps/policies/*.hcl and entities/platform/policies/*.hcl each
  # feed their own instance of this module independently. One *.hcl file ==
  # one Vault policy, named after the file.
  policy_files = fileset("${path.root}/policies", "*.hcl")

  policy_names = toset([
    for file in local.policy_files : trimsuffix(file, ".hcl")
  ])

  # Rendered into policy templates as ${mount_paths.<key>}, so a policy never
  # hardcodes a mount path that only exists as a variable here.
  policy_template_vars = {
    mount_paths = { for name, mount in var.kv_mounts : name => mount.path }
  }

  # --- GitHub team -> Vault policy mapping -------------------------------
  #
  # Resolves the policy NAMES in var.github_team_policies against the actual
  # vault_policy resources, so Terraform orders policy creation before the
  # mapping that consumes it and fails at plan time on a typo.
  github_team_policies = {
    for team, names in var.github_team_policies :
    team => [for name in names : vault_policy.this[name].name]
  }
}
