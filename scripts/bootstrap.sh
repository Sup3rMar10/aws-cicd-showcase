#!/usr/bin/env bash
# One-time setup of what Terraform itself cannot create (it needs them to run): the remote-state bucket, GitHub's
# OIDC trust, and the two roles GitHub Actions assumes. Safe to re-run.
#
#   aws sso login   # or any way of getting admin-level credentials for a sandbox account
#   scripts/bootstrap.sh <github-owner>/<repo> [region]
set -euo pipefail

REPO="${1:?usage: bootstrap.sh <github-owner>/<repo> [region]}"
REGION="${2:-us-east-1}"
NAME="aws-cicd-showcase"
HERE="$(cd "$(dirname "$0")" && pwd)"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${NAME}-tfstate-${ACCOUNT}"
OIDC_ARN="arn:aws:iam::${ACCOUNT}:oidc-provider/token.actions.githubusercontent.com"
echo "account $ACCOUNT, region $REGION, state bucket $BUCKET"

render() {  # fill the ${PLACEHOLDERS} in a policy template
  sed -e "s|\${ACCOUNT}|$ACCOUNT|g" -e "s|\${BUCKET}|$BUCKET|g" -e "s|\${NAME}|$NAME|g" \
      -e "s|\${REPO}|$REPO|g" -e "s|\${OIDC_ARN}|$OIDC_ARN|g" "$HERE/policies/$1"
}

echo "== 1. Terraform state bucket (versioned, encrypted, private)"
if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=$REGION" >/dev/null
  fi
fi
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "== 2. GitHub OIDC identity provider (no long-lived keys anywhere)"
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com >/dev/null
fi

echo "== 3. Roles for GitHub Actions"
upsert_role() {  # name, trust-template
  if aws iam get-role --role-name "$1" >/dev/null 2>&1; then
    aws iam update-assume-role-policy --role-name "$1" --policy-document "$(render "$2")"
  else
    aws iam create-role --role-name "$1" --assume-role-policy-document "$(render "$2")" >/dev/null
  fi
}

# Deploy role: only jobs in this repo's `prod` environment can assume it.
upsert_role "${NAME}-github-deploy" trust-deploy.json.tpl
aws iam put-role-policy --role-name "${NAME}-github-deploy" --policy-name deploy \
  --policy-document "$(render deploy-permissions.json.tpl)"

# Plan role: only pull-request jobs, read-only on AWS plus access to the state bucket.
upsert_role "${NAME}-github-plan" trust-plan.json.tpl
aws iam attach-role-policy --role-name "${NAME}-github-plan" --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
aws iam put-role-policy --role-name "${NAME}-github-plan" --policy-name state \
  --policy-document "$(render state-access.json.tpl)"

echo "== 4. GitHub repository variables"
if command -v gh >/dev/null 2>&1; then
  gh variable set AWS_REGION --repo "$REPO" --body "$REGION"
  gh variable set TF_STATE_BUCKET --repo "$REPO" --body "$BUCKET"
  gh variable set AWS_DEPLOY_ROLE_ARN --repo "$REPO" --body "arn:aws:iam::${ACCOUNT}:role/${NAME}-github-deploy"
  gh variable set AWS_PLAN_ROLE_ARN --repo "$REPO" --body "arn:aws:iam::${ACCOUNT}:role/${NAME}-github-plan"
else
  echo "gh CLI not found; set these repository variables by hand:"
  echo "  AWS_REGION=$REGION  TF_STATE_BUCKET=$BUCKET"
  echo "  AWS_DEPLOY_ROLE_ARN=arn:aws:iam::${ACCOUNT}:role/${NAME}-github-deploy"
  echo "  AWS_PLAN_ROLE_ARN=arn:aws:iam::${ACCOUNT}:role/${NAME}-github-plan"
fi

echo
echo "Done. Next: create a 'prod' environment in the repo settings (add yourself as a required reviewer if you want an"
echo "approval gate), then run the Deploy workflow from the Actions tab."
