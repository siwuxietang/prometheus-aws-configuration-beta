## Project: app-ecs-container-instances

Create ECS container instances



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| additional_tags | Stack specific tags to apply | map | `<map>` | no |
| autoscaling_group_desired_capacity | Desired number of ECS container instances | string | `1` | no |
| autoscaling_group_max_size | Maximum desired number of ECS container instances | string | `1` | no |
| autoscaling_group_min_size | Minimum desired number of ECS container instances | string | `1` | no |
| aws_region | AWS region | string | `eu-west-1` | no |
| ecs_image_id | AMI ID to use for the ECS container instances | string | `ami-2d386654` | no |
| ecs_instance_root_size | ECS instance root volume size - in GB | string | `50` | no |
| ecs_instance_ssh_keyname | SSH keyname for ECS instances | string | `ecs-monitoring-ssh-test` | no |
| ecs_instance_type | EC2 instance type for container instances | string | `m4.xlarge` | no |
| remote_state_bucket | S3 bucket we store our terraform state in | string | `ecs-monitoring` | no |
| stack_name | Unique name for this collection of resources | string | `ecs-monitoring` | no |

## Outputs

| Name | Description |
|------|-------------|
| ecs_container_instance_asg_id | ecs-container-instance ASG ID |

