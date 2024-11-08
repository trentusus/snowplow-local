license {
  accept = env("ACCEPT_LICENSE")
}

source {
  use "kinesis" {
    stream_name       = "enriched-good"
    region            = "ap-southeast-2"
    app_name          = "snowbridge"
    concurrent_writes = 15
    custom_aws_endpoint = "http://localhost.localstack.cloud:4566"
    read_throttle_delay_ms = 500
    start_timestamp = env("START_TIMESTAMP")
  }
}

transform {
  use "spEnrichedFilter" {
    atomic_field = "app_id"
    regex = "^my-app-id$"
    filter_action = "keep"
  }
}

transform {
    use "spEnrichedToJson" {}
}

target {
  use "stdout" {}
}

failure_target {
    use "stdout" {}
}

// log level configuration (default: "info")
log_level = "info"
disable_telemetry = true