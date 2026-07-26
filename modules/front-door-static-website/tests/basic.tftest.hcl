mock_provider "azurerm" {
  mock_resource "azurerm_cdn_frontdoor_profile" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Cdn/profiles/learn-frontdoor"
    }
  }
  mock_resource "azurerm_cdn_frontdoor_endpoint" {
    defaults = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Cdn/profiles/learn-frontdoor/afdEndpoints/learn-static-endpoint-001"
      host_name = "learn-static-endpoint-001.z01.azurefd.net"
    }
  }
  mock_resource "azurerm_cdn_frontdoor_origin_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Cdn/profiles/learn-frontdoor/originGroups/static-site"
    }
  }
  mock_resource "azurerm_cdn_frontdoor_origin" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Cdn/profiles/learn-frontdoor/originGroups/static-site/origins/storage"
    }
  }
}

variables {
  name                = "learn-frontdoor"
  endpoint_name       = "learn-static-endpoint-001"
  resource_group_name = "learn-rg"
  origin_host_name    = "learnstaticweb001.z23.web.core.windows.net"
}

run "plans_modern_front_door" {
  command = plan

  assert {
    condition     = azurerm_cdn_frontdoor_route.this.https_redirect_enabled && azurerm_cdn_frontdoor_profile.this.sku_name != "Classic_AzureFrontDoor"
    error_message = "The route must redirect to HTTPS and must not use Front Door Classic."
  }
}

# https_redirect_enabled only redirects; it does not stop Front Door speaking
# plain HTTP to the origin. forwarding_protocol is the setting that does, and
# the two are easy to confuse, so they are pinned together.
run "traffic_is_https_end_to_end" {
  command = plan

  assert {
    condition = (
      azurerm_cdn_frontdoor_route.this.forwarding_protocol == "HttpsOnly" &&
      azurerm_cdn_frontdoor_route.this.https_redirect_enabled
    )
    error_message = "Front Door must redirect clients to HTTPS and reach the origin over HTTPS."
  }

  # Both protocols are accepted at the edge precisely so the redirect above has
  # something to catch; dropping Http would make plain-HTTP clients fail instead
  # of being redirected.
  assert {
    condition     = length(azurerm_cdn_frontdoor_route.this.supported_protocols) == 2
    error_message = "The edge must accept both Http and Https so the redirect can fire."
  }
}

# certificate_name_check_enabled is what makes the HTTPS hop to the origin
# actually verified rather than merely encrypted. It only works because
# origin_host_header is set to the storage hostname the certificate is issued
# for, so the two must stay in step.
run "origin_certificate_is_verified_against_the_right_hostname" {
  command = plan

  assert {
    condition = (
      azurerm_cdn_frontdoor_origin.this.certificate_name_check_enabled &&
      azurerm_cdn_frontdoor_origin.this.host_name == var.origin_host_name &&
      azurerm_cdn_frontdoor_origin.this.origin_host_header == var.origin_host_name
    )
    error_message = "The origin certificate must be verified against the same hostname it is addressed by."
  }
}

run "route_serves_the_whole_site_from_the_default_domain" {
  command = plan

  assert {
    condition = (
      contains(azurerm_cdn_frontdoor_route.this.patterns_to_match, "/*") &&
      azurerm_cdn_frontdoor_route.this.link_to_default_domain &&
      azurerm_cdn_frontdoor_route.this.enabled
    )
    error_message = "The route must serve every path on the default azurefd.net domain."
  }
}

# A single-origin group still needs a health probe, because Front Door will not
# serve from an origin it believes is down. HEAD on / keeps the probe cheap;
# 3-of-4 samples stops one slow response from taking the site out.
run "health_probe_and_load_balancing_defaults" {
  command = plan

  assert {
    condition = (
      azurerm_cdn_frontdoor_origin_group.this.health_probe[0].protocol == "Https" &&
      azurerm_cdn_frontdoor_origin_group.this.health_probe[0].request_type == "HEAD" &&
      azurerm_cdn_frontdoor_origin_group.this.health_probe[0].path == "/"
    )
    error_message = "The health probe must issue a cheap HTTPS HEAD against the site root."
  }

  assert {
    condition = (
      azurerm_cdn_frontdoor_origin_group.this.load_balancing[0].sample_size == 4 &&
      azurerm_cdn_frontdoor_origin_group.this.load_balancing[0].successful_samples_required == 3
    )
    error_message = "An origin must be considered healthy on 3 of the last 4 samples."
  }
}

run "sku_and_tags_reach_the_profile" {
  command = plan
  variables {
    sku_name = "Premium_AzureFrontDoor"
    tags     = { env = "learn" }
  }

  assert {
    condition = (
      azurerm_cdn_frontdoor_profile.this.sku_name == "Premium_AzureFrontDoor" &&
      azurerm_cdn_frontdoor_profile.this.tags["env"] == "learn" &&
      azurerm_cdn_frontdoor_endpoint.this.tags["env"] == "learn"
    )
    error_message = "The SKU and tags must reach the profile, and tags the endpoint too."
  }
}

# host_name is computed, so the outputs only resolve after a mocked apply.
run "exposes_the_hostname_a_visitor_uses" {
  command = apply

  assert {
    condition = (
      output.profile_id == azurerm_cdn_frontdoor_profile.this.id &&
      output.endpoint_id == azurerm_cdn_frontdoor_endpoint.this.id &&
      output.endpoint_host_name == azurerm_cdn_frontdoor_endpoint.this.host_name
    )
    error_message = "The profile, endpoint, and the public hostname must all be exposed."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

# The storage module's primary_web_endpoint output is a full URL, and pasting it
# straight in is the obvious mistake. Front Door wants the bare host.
run "rejects_an_origin_host_name_with_a_scheme" {
  command = plan
  variables {
    origin_host_name = "https://learnstaticweb001.z23.web.core.windows.net"
  }

  expect_failures = [var.origin_host_name]
}

run "rejects_front_door_classic" {
  command = plan
  variables {
    sku_name = "Classic_AzureFrontDoor"
  }

  expect_failures = [var.sku_name]
}

run "rejects_an_unknown_sku" {
  command = plan
  variables {
    sku_name = "Standard"
  }

  expect_failures = [var.sku_name]
}
