resource "aws_iam_instance_profile" "ecs_profile" {
  name = "${var.stack_name}-ecs-profile"
  role = "${aws_iam_role.container_instance_role.name}"
}

resource "aws_iam_role" "container_instance_role" {
  name = "${var.stack_name}-container-instance-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "ecs_container_instance_document" {
  statement {
    sid = "ECSContainerInstancePolicy"

    resources = ["*"]

    actions = [
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:Submit*",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

resource "aws_iam_policy" "ecs_container_instance_policy" {
  name   = "${var.stack_name}_ecs_container_instance_policy"
  path   = "/"
  policy = "${data.aws_iam_policy_document.ecs_container_instance_document.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_container_instance_document_policy_attachment" {
  role       = "${aws_iam_role.container_instance_role.name}"
  policy_arn = "${aws_iam_policy.ecs_container_instance_policy.arn}"
}
