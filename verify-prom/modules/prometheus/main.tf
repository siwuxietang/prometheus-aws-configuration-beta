terraform {
  required_version = ">= 0.11.2"
}

resource "aws_iam_instance_profile" "prometheus_config_reader_profile" {
  name = "prometheus_config_reader_profile"
  role = "${aws_iam_role.prometheus_config_reader.name}"
}

resource "aws_iam_role" "prometheus_config_reader" {
  name = "prometheus_config_reader"

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

resource "aws_iam_role_policy" "prometheus_config_reader_policy" {
  name = "prometheus_config_reader_policy"
  role = "${aws_iam_role.prometheus_config_reader.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.gds_prometheus_targets.arn}/*",
        "${aws_s3_bucket.gds_prometheus_targets.arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_instance" "prometheus" {
  ami                  = "${var.ami_id}"
  instance_type        = "m4.large"
  subnet_id            = "${aws_subnet.main.id}"
  user_data            = "${data.template_file.user_data_script.rendered}"
  iam_instance_profile = "${aws_iam_instance_profile.prometheus_config_reader_profile.id}"
  private_ip           = "${var.prom_priv_ip}"
  ebs_optimized        = true
  availability_zone    = "eu-west-1a"

vpc_security_group_ids = [
    "${aws_security_group.ssh_from_gds.id}",
    "${aws_security_group.http_outbound.id}",
    "${aws_security_group.external_http_traffic.id}",
    "${aws_security_group.logstash_outbound.id}",
  ]

  tags {
    Name = "Prometheus"
  }
}

resource "aws_volume_attachment" "attach-prometheus-disk" {
  device_name  = "${var.device_mount_path}"
  volume_id    = "${var.volume_to_attach}"
  instance_id  = "${aws_instance.prometheus.id}"
  skip_destroy = true
}

data "template_file" "user_data_script" {
  template = "${file("${path.module}/cloud.conf")}"

  vars {
    prometheus_version = "${var.prometheus_version}"
    domain_name        = "${var.domain_name}"
    lets_encrypt_email = "${var.lets_encrypt_email}"
    real_certificate   = "${var.real_certificate=="yes" ? "-v" : "--staging"}"
    logstash_endpoint  = "${var.logstash_endpoint}"
    logstash_port      = "${var.logstash_port}"
    config_bucket      = "${aws_s3_bucket.gds_prometheus_targets.id}"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_hostnames = true

  tags {
    Name = "Reliability Engineering - Prometheus VPC"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "main"
  }
}

resource "aws_subnet" "main" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${aws_vpc.main.cidr_block}"
  map_public_ip_on_launch = true

  tags {
    Name = "Main"
  }
}

resource "aws_security_group" "ssh_from_gds" {
  vpc_id      = "${aws_vpc.main.id}"
  name        = "SSH from GDS"
  description = "Allow SSH access from GDS"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["${var.cidr_admin_whitelist}"]
  }

  tags {
    Name = "SSH from GDS"
  }
}

resource "aws_security_group" "http_am_from_gds_vpn_internal" {
  vpc_id      = "${aws_vpc.main.id}"
  name        = "Intenral access to alert manager UI"
  description = "Allow  GDS user access to the prometheus UI, including also internal VPC access"

  ingress {
    protocol    = "tcp"
    from_port   = 9093
    to_port     = 9093
    cidr_blocks = ["${var.cidr_admin_whitelist}"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 9093
    to_port     = 9093
    cidr_blocks = ["10.0.0.0/24"]
  }

  tags {
    Name = "Intenral access to alert manager UI from GDS"
  }
}

resource "aws_security_group" "http_outbound" {
  vpc_id      = "${aws_vpc.main.id}"
  name        = "HTTP outbound"
  description = "Allow HTTP connections out to the internet"

  egress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "tcp"
    from_port   = 9093
    to_port     = 9093
    cidr_blocks = ["10.0.0.0/24"]
  }

  tags {
    Name = "HTTP outbound"
  }
}

resource "aws_security_group" "logstash_outbound" {
  vpc_id      = "${aws_vpc.main.id}"
  name        = "Logstash outbound"
  description = "Allow connections to our ELK provider"

  egress {
    protocol    = "tcp"
    from_port   = "${var.logstash_port}"
    to_port     = "${var.logstash_port}"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "external_http_traffic" {
  vpc_id      = "${aws_vpc.main.id}"
  name        = "external_http_traffic"
  description = "Allow external http traffic"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "external-http-traffic"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main.id}"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.main.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_eip" "eip_prometheus" {
  vpc = true
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = "${aws_instance.prometheus.id}"
  allocation_id = "${aws_eip.eip_prometheus.id}"
}

resource "aws_route53_zone" "main" {
  name = "gds-reliability.engineering"
}

resource "aws_route53_zone" "metrics" {
  name = "metrics.gds-reliability.engineering"
}

resource "aws_route53_record" "metrics" {
  zone_id = "${aws_route53_zone.main.zone_id}"
  name    = "metrics.gds-reliability.engineering"
  type    = "NS"
  ttl     = "3600"

  records = [
    "${aws_route53_zone.metrics.name_servers.0}",
    "${aws_route53_zone.metrics.name_servers.1}",
    "${aws_route53_zone.metrics.name_servers.2}",
    "${aws_route53_zone.metrics.name_servers.3}",
  ]
}

resource "aws_route53_record" "prometheus_www" {
  zone_id = "${aws_route53_zone.metrics.zone_id}"
  name    = "metrics.gds-reliability.engineering"
  type    = "A"
  ttl     = "3600"
  records = ["${aws_eip.eip_prometheus.public_ip}"]
}

resource "aws_s3_bucket" "gds_prometheus_targets" {
  bucket = "gds-prometheus-targets-test"
  acl    = "private"

  versioning {
    enabled = true
  }
}

resource "aws_iam_user" "cf_app_discovery" {
  name = "cf_app_discovery_raw"
  path = "/system/"
}

resource "aws_iam_user_policy" "cf_app_discovery_bucket_access" {
  name = "cf_app_discovery_bucket_access"
  user = "${aws_iam_user.cf_app_discovery.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.gds_prometheus_targets.arn}/*",
        "${aws_s3_bucket.gds_prometheus_targets.arn}"
      ]
    }
  ]
}
EOF
}
