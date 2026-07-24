mock_provider "azurerm" {
  mock_resource "azurerm_cdn_frontdoor_profile" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Cdn/profiles/learn-frontdoor"
    }
  }
  mock_resource "azurerm_cdn_frontdoor_endpoint" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Cdn/profiles/learn-frontdoor/afdEndpoints/learn-static-endpoint-001"
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

run "plans_modern_front_door" {
  command = plan
  variables {
    name                = "learn-frontdoor"
    endpoint_name       = "learn-static-endpoint-001"
    resource_group_name = "learn-rg"
    origin_host_name    = "learnstaticweb001.z23.web.core.windows.net"

  }
  assert {
    condition     = azurerm_cdn_frontdoor_route.this.https_redirect_enabled && azurerm_cdn_frontdoor_profile.this.sku_name != "Classic_AzureFrontDoor"
    error_message = "The route must redirect to HTTPS and must not use Front Door Classic."

  }
}
