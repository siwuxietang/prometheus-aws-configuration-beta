remote_state_bucket = "prometheus-staging"
stack_name = "staging"
dev_environment = "false"
prometheus_subdomain = "monitoring-staging"
targets_s3_bucket = "gds-prometheus-targets-staging"
additional_tags = {
  "Environment" = "staging"
}
