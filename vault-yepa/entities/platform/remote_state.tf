# See entities/apps/remote_state.tf — same pattern, this entity's own key.

data "terraform_remote_state" "core" {
  backend = "remote"

  config = {
    organization = "yepa" # TODO: keep in sync with backend.tf
    workspaces = {
      name = "vault-yepa-core"
    }
  }
}
