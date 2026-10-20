# ---------------------------------------------------------------------------
# Reads core's outputs — specifically, the Vault namespace path it created
# for this entity — from its HCP Terraform state.
#
# Requires "Remote state sharing" enabled from vault-yepa-core to
# vault-yepa-apps in HCP Terraform (core workspace -> Settings -> Sharing),
# and that this workspace runs in the same HCP Terraform organization the
# `cloud` block in backend.tf already points at.
#
# Deliberately not var-driven, for the same reason as the `cloud` block:
# keep this in sync with backend.tf by hand if you rename the organization.
# ---------------------------------------------------------------------------

data "terraform_remote_state" "core" {
  backend = "remote"

  config = {
    organization = "yepa" # TODO: keep in sync with backend.tf
    workspaces = {
      name = "vault-yepa-core"
    }
  }
}
