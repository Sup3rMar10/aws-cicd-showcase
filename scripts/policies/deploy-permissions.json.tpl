{
  "Version": "2012-10-17",
  "Statement": [
    {"Sid": "TerraformState", "Effect": "Allow", "Action": "s3:ListBucket", "Resource": "arn:aws:s3:::${BUCKET}"},
    {"Sid": "TerraformStateObjects", "Effect": "Allow", "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
     "Resource": "arn:aws:s3:::${BUCKET}/*"},

    {"Sid": "EcrLogin", "Effect": "Allow", "Action": "ecr:GetAuthorizationToken", "Resource": "*"},
    {"Sid": "EcrRepository", "Effect": "Allow", "Action": "ecr:*",
     "Resource": "arn:aws:ecr:*:${ACCOUNT}:repository/${NAME}"},

    {"Sid": "ServiceLevelCompute", "Effect": "Allow",
     "Action": ["ec2:*", "elasticloadbalancing:*", "ecs:*", "application-autoscaling:*", "cloudwatch:*"], "Resource": "*"},

    {"Sid": "LogsDescribe", "Effect": "Allow", "Action": ["logs:DescribeLogGroups", "logs:ListTagsForResource"], "Resource": "*"},
    {"Sid": "LogsOwnGroup", "Effect": "Allow", "Action": "logs:*",
     "Resource": ["arn:aws:logs:*:${ACCOUNT}:log-group:/ecs/${NAME}", "arn:aws:logs:*:${ACCOUNT}:log-group:/ecs/${NAME}:*"]},

    {"Sid": "OwnTopics", "Effect": "Allow", "Action": "sns:*", "Resource": "arn:aws:sns:*:${ACCOUNT}:${NAME}-*"},

    {"Sid": "OwnRoles", "Effect": "Allow",
     "Action": ["iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole", "iam:UntagRole", "iam:UpdateAssumeRolePolicy",
                "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies",
                "iam:ListInstanceProfilesForRole", "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy"],
     "Resource": "arn:aws:iam::${ACCOUNT}:role/${NAME}-*"},
    {"Sid": "PassOnlyToEcsTasks", "Effect": "Allow", "Action": "iam:PassRole",
     "Resource": "arn:aws:iam::${ACCOUNT}:role/${NAME}-*",
     "Condition": {"StringEquals": {"iam:PassedToService": "ecs-tasks.amazonaws.com"}}},
    {"Sid": "ServiceLinkedRoles", "Effect": "Allow", "Action": "iam:CreateServiceLinkedRole", "Resource": "*",
     "Condition": {"StringEquals": {"iam:AWSServiceName": [
       "ecs.amazonaws.com", "elasticloadbalancing.amazonaws.com", "ecs.application-autoscaling.amazonaws.com"]}}}
  ]
}
