mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code = 200, response_body = "ok"

    }

  }
}

run "accepts_expected_status" {
  command = plan
  variables {
    url = "https://example.test/health"

  }
  assert {
    condition     = data.http.this.status_code == 200
    error_message = "The mocked endpoint should be healthy."

  }
  assert {
    condition     = output.status_code == 200
    error_message = "status_code must surface the observed status."

  }
}

run "rejects_non_http_url" {
  command = plan
  variables {
    url = "ftp://example.test/health"
  }

  expect_failures = [var.url]
}

run "rejects_zero_timeout" {
  command = plan
  variables {
    url        = "https://example.test/health"
    timeout_ms = 0
  }

  expect_failures = [var.timeout_ms]
}
