#!/usr/bin/env bash
# Delete everything the pipeline created, so nothing keeps billing (the load balancer alone is roughly $16/month).
#   scripts/teardown.sh <github-owner>/<repo> [region] [--include-bootstrap]
# Needs the same credentials as bootstrap.sh.
set -euo pipefail

REPO="${1:?usage: teardown.sh <github-owner>/<repo> [region] [--include-bootstrap]}"
REGION="${2:-us-east-1}"
NAME="aws-cicd-showcase"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${NAME}-tfstate-${ACCOUNT}"

echo "== destroying the application stack"
cd "$(dirname "$0")/../infra"
terraform init -reconfigure -input=false -backend-config="bucket=$BUCKET" \
  -backend-config="key=${NAME}/terraform.tfstate" -backend-config="region=$REGION"
terraform destroy -auto-approve -input=false -var image_tag=teardown

if [ "${3:-}" = "--include-bootstrap" ]; then
  echo "== removing the bootstrap resources (state bucket, roles)"
  # a versioned bucket must have every object version and delete marker removed before it can be deleted
  for kind in Versions DeleteMarkers; do
    aws s3api list-object-versions --bucket "$BUCKET" --query "${kind}[].[Key,VersionId]" --output text |
      while read -r key vid; do
        if [ -n "$key" ] && [ "$key" != "None" ]; then
          aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$vid" >/dev/null
        fi
      done
  done
  aws s3api delete-bucket --bucket "$BUCKET" --region "$REGION" || echo "could not delete the bucket; remove it in the console"
  aws iam delete-role-policy --role-name "${NAME}-github-deploy" --policy-name deploy || true
  aws iam delete-role --role-name "${NAME}-github-deploy" || true
  aws iam detach-role-policy --role-name "${NAME}-github-plan" --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess || true
  aws iam delete-role-policy --role-name "${NAME}-github-plan" --policy-name state || true
  aws iam delete-role --role-name "${NAME}-github-plan" || true
  echo "left in place: the GitHub OIDC provider (other projects may use it). Delete it in IAM if you want it gone."
fi
echo "done ($REPO)"
