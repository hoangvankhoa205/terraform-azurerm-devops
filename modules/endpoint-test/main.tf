data "http" "this" {
  url                = var.url
  request_headers    = var.request_headers
  request_timeout_ms = var.timeout_ms

  retry {
    attempts     = 3
    min_delay_ms = 250
    max_delay_ms = var.timeout_ms

  }
}

# A check block reports a FAILED assertion as a warning, not an error: a bad
# status will not fail `terraform apply` or change the exit code. That is
# deliberate — post-deployment verification should not leave a half-applied
# root — but it means this module observes an endpoint rather than gates on it.
# For a hard failure, assert on the status_code output from `terraform test`.
check "expected_status" {
  assert {
    condition     = data.http.this.status_code == var.expected_status
    error_message = "${var.url} returned ${data.http.this.status_code}; expected ${var.expected_status}."

  }
}
