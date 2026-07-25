output "status_code" {
  description = "Observed HTTP status code."
  value       = data.http.this.status_code
}
output "response_body" {
  description = "Observed response body; treat it as potentially sensitive application data."
  value       = data.http.this.response_body
  sensitive   = true
}
