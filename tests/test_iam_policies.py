"""The IAM policy templates are rendered the way bootstrap.sh renders them and checked, with no AWS account needed."""
import glob
import json
import os

import pytest

POLICY_DIR = os.path.join(os.path.dirname(__file__), "..", "scripts", "policies")
VALUES = {
    "${ACCOUNT}": "123456789012",
    "${BUCKET}": "aws-cicd-showcase-tfstate-123456789012",
    "${NAME}": "aws-cicd-showcase",
    "${REPO}": "someone/aws-cicd-showcase",
    "${OIDC_ARN}": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com",
}
SUB = "token.actions.githubusercontent.com:sub"
AUD = "token.actions.githubusercontent.com:aud"


def render(filename: str) -> dict:
    with open(os.path.join(POLICY_DIR, filename), encoding="utf-8") as f:
        text = f.read()
    for placeholder, value in VALUES.items():
        text = text.replace(placeholder, value)
    assert "${" not in text, "unfilled placeholder"
    return json.loads(text)


def actions(statement) -> list[str]:
    a = statement["Action"]
    return [a] if isinstance(a, str) else a


@pytest.mark.parametrize("path", sorted(glob.glob(os.path.join(POLICY_DIR, "*.tpl"))))
def test_every_template_renders_to_valid_json(path):
    assert render(os.path.basename(path))["Version"] == "2012-10-17"


def test_deploy_role_can_only_be_assumed_from_the_prod_environment():
    cond = render("trust-deploy.json.tpl")["Statement"][0]["Condition"]["StringEquals"]
    assert cond[SUB] == "repo:someone/aws-cicd-showcase:environment:prod"
    assert cond[AUD] == "sts.amazonaws.com"


def test_plan_role_can_only_be_assumed_from_pull_requests():
    cond = render("trust-plan.json.tpl")["Statement"][0]["Condition"]["StringEquals"]
    assert cond[SUB] == "repo:someone/aws-cicd-showcase:pull_request"


def test_trust_policies_never_use_wildcard_subjects():
    for name in ("trust-deploy.json.tpl", "trust-plan.json.tpl"):
        assert "*" not in render(name)["Statement"][0]["Condition"]["StringEquals"][SUB]


def test_deploy_permissions_have_no_admin_wildcards():
    for st in render("deploy-permissions.json.tpl")["Statement"]:
        assert st["Effect"] == "Allow"
        # service-level wildcards like "ecs:*" are deliberate; a bare "*" action is not
        assert "*" not in actions(st), st["Sid"]
        assert "iam:*" not in actions(st), st["Sid"]


def test_iam_and_passrole_are_confined_to_this_projects_roles():
    statements = {st["Sid"]: st for st in render("deploy-permissions.json.tpl")["Statement"]}
    assert statements["OwnRoles"]["Resource"] == "arn:aws:iam::123456789012:role/aws-cicd-showcase-*"
    passrole = statements["PassOnlyToEcsTasks"]
    assert passrole["Condition"]["StringEquals"]["iam:PassedToService"] == "ecs-tasks.amazonaws.com"
