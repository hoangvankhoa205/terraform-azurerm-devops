# Front Door in front of a Storage static website, on the default
# *.azurefd.net hostname. A custom domain, WAF policy, and Private Link to the
# origin are the caller's — this module builds the five resources that have to
# exist before any of those become possible.
#
# Front Door Standard/Premium models one site as a chain, and all five links are
# required: a profile owns an endpoint (the hostname), an origin group (the
# health and load-balancing policy), and an origin (the backend); a route then
# joins the endpoint to the origin group. There is no shorter arrangement.

resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  sku_name            = var.sku_name
  tags                = var.tags
}

# The endpoint owns the public hostname, <endpoint_name>.z01.azurefd.net, so
# endpoint_name has to be globally unique where the profile name does not.
resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = var.endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  tags                     = var.tags
}

# Names here are fixed rather than derived from var.name. They are scoped to the
# profile, never appear in a URL, and a caller has no reason to choose them —
# but changing one would force a replace, so they stay pinned.
resource "azurerm_cdn_frontdoor_origin_group" "this" {
  name                     = "static-site"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  # A static site holds no server-side session, so pinning a visitor to one
  # origin buys nothing and only makes edge caching less effective.
  session_affinity_enabled = false

  load_balancing {
    # With a single origin there is nothing to balance between, so these values
    # only govern how quickly Front Door decides the origin is healthy again.
    # Requiring 3 of the last 4 probes stops one slow response taking the site
    # offline, while still recovering inside a few probe intervals.
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }

  health_probe {
    # HEAD rather than GET, and against the site root, so the probe costs a
    # response header rather than the whole index page. Two minutes is
    # deliberately relaxed: probes are billed, and a static origin in Azure
    # Storage rarely fails on its own.
    interval_in_seconds = 120
    path                = "/"
    protocol            = "Https"
    request_type        = "HEAD"
  }
}

resource "azurerm_cdn_frontdoor_origin" "this" {
  name                          = "storage"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  enabled                       = true

  # certificate_name_check_enabled is what makes the hop to the origin verified
  # rather than merely encrypted. It only works because origin_host_header is
  # the same hostname the storage certificate is issued for; setting a different
  # host header here would break certificate validation.
  certificate_name_check_enabled = true
  host_name                      = var.origin_host_name
  origin_host_header             = var.origin_host_name

  http_port  = 80
  https_port = 443

  # Priority and weight only matter with more than one origin. They are the
  # provider's required defaults for a single-origin group.
  priority = 1
  weight   = 1000
}

resource "azurerm_cdn_frontdoor_route" "this" {
  name                          = "static-site"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.this.id]
  enabled                       = true

  # Two separate settings that are easy to confuse. forwarding_protocol governs
  # the hop from Front Door to the origin; https_redirect_enabled governs the
  # hop from the visitor to Front Door. Both are needed for HTTPS end to end.
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true

  # Http is accepted at the edge precisely so the redirect above has something
  # to catch. Dropping it would make plain-HTTP visitors fail rather than be
  # redirected.
  patterns_to_match   = ["/*"]
  supported_protocols = ["Http", "Https"]

  link_to_default_domain = true
}
