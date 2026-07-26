mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 200
      response_body = "ok"
    }
  }
}

variables {
  url = "https://example.test/health"
}

run "accepts_expected_status" {
  command = plan

  assert {
    condition     = data.http.this.status_code == 200
    error_message = "The mocked endpoint should be healthy."
  }

  assert {
    condition     = output.status_code == 200
    error_message = "status_code must surface the observed status."
  }
}

run "surfaces_the_response_body" {
  command = plan

  assert {
    condition     = output.response_body == "ok"
    error_message = "response_body must surface the observed body."
  }
}

run "passes_request_headers_through" {
  command = plan
  variables {
    request_headers = { Accept = "application/json" }
  }

  assert {
    condition     = data.http.this.request_headers["Accept"] == "application/json"
    error_message = "request_headers must reach the HTTP request."
  }
}

run "timeout_reaches_the_request" {
  command = plan
  variables {
    timeout_ms = 2500
  }

  assert {
    condition     = data.http.this.request_timeout_ms == 2500
    error_message = "timeout_ms must reach request_timeout_ms."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# THE CHECK BLOCK — the module's whole point, and its most surprising behaviour
# ---------------------------------------------------------------------------------------------------------------------

# The headline caveat in the README, pinned as a test: a mismatched status makes
# the check FAIL, and `expect_failures` is what proves it fired. In a real
# `terraform apply` this same failure is only a warning and the exit code stays
# 0 — which is exactly why a pipeline that checks nothing but the exit code will
# report success while the site serves errors.
run "check_fails_when_the_status_does_not_match" {
  command = plan
  variables {
    expected_status = 404
  }

  expect_failures = [check.expected_status]
}

# The mirror of the run above: a non-default expected_status that DOES match is
# honoured, so the check is comparing against the variable rather than a
# hard-coded 200.
run "accepts_a_non_default_expected_status" {
  command = plan
  variables {
    expected_status = 200
  }

  assert {
    condition     = data.http.this.status_code == var.expected_status
    error_message = "The check must compare against expected_status, not a hard-coded 200."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

run "rejects_non_http_url" {
  command = plan
  variables {
    url = "ftp://example.test/health"
  }

  expect_failures = [var.url]
}

run "rejects_url_with_no_scheme" {
  command = plan
  variables {
    url = "example.test/health"
  }

  expect_failures = [var.url]
}

run "rejects_zero_timeout" {
  command = plan
  variables {
    timeout_ms = 0
  }

  expect_failures = [var.timeout_ms]
}

run "rejects_negative_timeout" {
  command = plan
  variables {
    timeout_ms = -1
  }

  expect_failures = [var.timeout_ms]
}
