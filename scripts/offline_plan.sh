#!/usr/bin/env bash
# Credential-free `terraform plan`: no AWS account, no remote state, no API calls.
# It checks that the configuration is internally consistent (every reference resolves, every argument is valid for the
# provider schema, the dependency graph builds) and prints what a first apply would create.
set -euo pipefail
cd "$(dirname "$0")/../infra"
trap 'rm -f backend_override.tf' EXIT
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf   # swap the S3 backend for a throwaway local one
export AWS_ACCESS_KEY_ID=offline AWS_SECRET_ACCESS_KEY=offline AWS_REGION=us-east-1
terraform init -reconfigure -input=false >/dev/null
terraform plan -input=false -no-color -var offline=true -var image_tag=offline-check -out=offline.tfplan | tail -n 30
rm -f offline.tfplan
