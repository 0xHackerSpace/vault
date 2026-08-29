# ---------------------------------------------------------------------------
# Terraform state backend
#
# IMPORTANT — the Terraform state of this root module is *sensitive*.
# Even though this configuration deliberately stores no secret values, the
# state still contains the full text of every Vault policy, the GitHub
# organisation, mount layout and auth configuration. That is a map of the
# authorisation model and must be treated as confidential.
#
# Requirements for whichever backend you pick:
#   * encryption at rest;
#   * state locking (concurrent applies must be impossible);
#   * versioning, so a bad apply can be rolled back;
#   * access restricted to the platform-engineering team / CI role.
#
# The backend is left undeclared (local state) so the module can be planned
# from a laptop out of the box. Uncomment and adapt ONE of the examples below
# before using this in a shared environment.
# ---------------------------------------------------------------------------

# terraform {
#   backend "s3" {
#     bucket       = "acme-terraform-state"
#     key          = "vault/platform/terraform.tfstate"
#     region       = "us-east-1"
#     encrypt      = true
#     kms_key_id   = "alias/terraform-state"
#     use_lockfile = true # S3-native locking (Terraform >= 1.10)
#   }
# }

# terraform {
#   backend "gcs" {
#     bucket = "acme-terraform-state"
#     prefix = "vault/platform"
#   }
# }

# terraform {
#   backend "azurerm" {
#     resource_group_name  = "acme-tfstate"
#     storage_account_name = "acmetfstate"
#     container_name       = "tfstate"
#     key                  = "vault/platform.tfstate"
#   }
# }
