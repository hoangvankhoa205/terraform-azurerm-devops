terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = ">= 3.5.0, < 4.0.0"

    }

  }
}
