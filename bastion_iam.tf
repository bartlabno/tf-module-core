data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "bastion_ec2" {
  name = "bastion-role-${local.suffix}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  count = var.create_bastion_host ? 1 : 0
}

resource "aws_iam_instance_profile" "bastion_ec2_profile" {
  name  = "bastion-pro-${local.suffix}"
  role  = aws_iam_role.bastion_ec2[0].id
  count = var.create_bastion_host ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "bastion_pol_attach" {
  role       = aws_iam_role.bastion_ec2[0].id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  count      = var.create_bastion_host ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "ssm_pol_attach" {
  role       = aws_iam_role.bastion_ec2[0].id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMManagedInstanceCore"
  count      = var.create_bastion_host ? 1 : 0
}

resource "aws_iam_group" "bastion_users" {
  name  = "bastion_users-grp-${local.suffix}"
  count = (var.create_bastion_host) ? 1 : 0
}

resource "aws_iam_policy" "session_manager" {
  name = "bastion_session_manager-pol-${local.suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "ssm:StartSession"
        Resource = [
          "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"
        ]
        Condition = {
          StringLike = {
            "ssm:resourceTag/aws:autoscaling:groupName" : [aws_autoscaling_group.bastion[0].name]
          }
        }
        Effect = "Allow"
      },
      {
        Action = [
          "ssm:ResumeSession",
          "ssm:TerminateSession"
        ],
        Resource = [
          "arn:aws:ssm:*:*:session/$${aws:username}-*"
        ]
        Effect = "Allow"
      },
      {
        Action = [
          "ssm:StartSession",
          "ssm:GetDocument",
          "ssm:ListDocuments"
        ],
        Resource = [
          "arn:aws:ssm:*:*:document/AWS-StartPortForwardingSession"
        ]
        Effect = "Allow"
      },
      {
        Action   = "ec2:DescribeInstances"
        Resource = "*"
        Effect   = "Allow"
      },
      {
        Action   = "iam:ListAccountAliases"
        Resource = "*"
        Effect   = "Allow"
      }
    ]
  })

  count = (var.create_bastion_host) ? 1 : 0
}

resource "aws_iam_group_policy_attachment" "ssm_pol_attach" {
  group      = aws_iam_group.bastion_users[0].id
  policy_arn = aws_iam_policy.session_manager[0].arn
  count      = (var.create_bastion_host) ? 1 : 0
}