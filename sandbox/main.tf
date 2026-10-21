provider "vault" {
  address = var.vault_addr
  token   = var.vault_token
}  


resource "vault_github_auth_backend" "hackerspace" {
  organization = "0xHackerSpace"
  path         = "hackerspace"
}
resource "vault_github_auth_backend" "example" {
  organization = "a-rabbit-hole"
  path         = "a-rabbit-hole"
}

# Hackerspace
# vault login -path=hackerspace -method=github token=$(gh auth token)

resource "vault_github_team" "hs_admins" {
  backend  = vault_github_auth_backend.hackerspace.id
  team     = "admins"
  policies = [vault_policy.admins.name]
}
resource "vault_github_team" "hs_maintainers" {
  backend  = vault_github_auth_backend.hackerspace.id
  team     = "maintainers"
  policies = [vault_policy.maintainers.name]
}
resource "vault_github_team" "hs_contributors" {
  backend  = vault_github_auth_backend.hackerspace.id
  team     = "contributors"
  policies = [vault_policy.contributors.name]
}
# resource "vault_github_team" "hs_wxyz-contributors" {
#   backend  = vault_github_auth_backend.hackerspace.id
#   team     = "wxyz-contributors"
#   policies = [vault_policy.wxyz-contributors.name]
# }

# hackerspace policy


resource "vault_policy" "admins" {
  name            = "admins"

  policy = file("./policies/admins.hcl")

}
resource "vault_policy" "maintainers" {
  name            = "maintainers"

  policy = file("./policies/maintainers.hcl")

}
resource "vault_policy" "contributors" {
  name            = "contributors"

  policy = file("./policies/contributors.hcl")

}
resource "vault_policy" "wxyz-contributors" {
  name            = "wxyz-contributors"

  policy = file("./policies/wxyz-contributors.hcl")

}

# identity groups
resource "vault_identity_group" "wxyz" {
  name     = "wxyz-contributors"
  type     = "external"
  policies = [vault_policy.wxyz-contributors.name]
  metadata = {
    team = "wxyz-contributors"
    projeto = "wxyz"
    organization = "0xHackerSpace"
  }


}
resource "vault_identity_group_alias" "wxyz" {
  name           = "wxyz-contributors"
  mount_accessor = vault_github_auth_backend.hackerspace.accessor
  canonical_id   = vault_identity_group.wxyz.id
}

# kv 

# resource "vault_mount" "kvv2" {
#   path        = "secret"
#   type        = "kv"
#   options     = { version = "2" }
#   description = "KV Version 2 secret engine mount"
# }

resource "vault_kv_secret_v2" "example" {
  mount               = "secret"
  name                = "admins/data"
  cas                 = 1
  delete_all_versions = true
  data_json = jsonencode(
    {
      zip = "zap",
      foo = "bar"
    }
  )
}
resource "vault_kv_secret_v2" "contributors" {
  mount               = "secret"
  name                = "contributors/data"
  cas                 = 1
  delete_all_versions = true
  data_json = jsonencode(
    {
      zip = "zap",
      foo = "bar"
    }
  )
}
resource "vault_kv_secret_v2" "wxyz-contributors" {
  mount               = "secret"
  name                = "wxyz-contributors/data"
  cas                 = 1
  delete_all_versions = true
  data_json = jsonencode(
    {
      zip = "zap",
      foo = "bar"
    }
  )
}