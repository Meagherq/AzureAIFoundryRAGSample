terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
  }
}

resource "azurerm_cognitive_account" "account" {
  name                          = "cog-${var.name}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  kind                          = "AIServices"
  project_management_enabled    = true
  custom_subdomain_name         = "cog-${var.name}"
  public_network_access_enabled = !var.enable_private_networking
  local_auth_enabled            = false

  network_acls {
    default_action = var.enable_private_networking ? "Deny" : "Allow"
    bypass         = "AzureServices"
  }

  sku_name = "S0"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azapi_update_resource" "agent_network_injection" {
  type        = "Microsoft.CognitiveServices/accounts@2025-06-01"
  resource_id = azurerm_cognitive_account.account.id

  body = {
    properties = {
      networkInjections = [
        {
          scenario                   = "agent"
          subnetArmId                = var.agent_subnet_id
          useMicrosoftManagedNetwork = false
        }
      ]
    }
  }
}

resource "azurerm_private_endpoint" "account" {
  name                = "pe-cog-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-cog-${var.name}"
    private_connection_resource_id = azurerm_cognitive_account.account.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  # DNS zone groups are configured manually for this repository.
  # private_dns_zone_group {
  #   name                 = "pdzg-cog-${var.name}"
  #   private_dns_zone_ids = var.private_dns_zone_ids
  # }

  tags = var.tags
}
