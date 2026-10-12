terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial backend config: the bucket, key and region are passed with -backend-config at `terraform init`
  # time (see scripts/bootstrap.sh and the workflows). use_lockfile gives S3-native state locking, so no
  # DynamoDB table is needed.
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}

# Credentials come from the environment: short-lived OIDC credentials in CI (no stored keys), or your own
# AWS profile locally. `offline = true` skips every call to AWS so `terraform plan` can run with dummy keys in
# pull requests from forks and in the credential-free CI check.
provider "aws" {
  region                      = var.region
  skip_credentials_validation = var.offline
  skip_requesting_account_id  = var.offline
  skip_metadata_api_check     = var.offline

  default_tags {
    tags = {
      Project   = var.name
      ManagedBy = "terraform"
    }
  }
}
