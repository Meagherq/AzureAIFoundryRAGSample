resource "azurerm_search_service" "search" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku             = var.sku
  replica_count   = var.replica_count
  partition_count = var.partition_count

  public_network_access_enabled = var.public_network_access_enabled

  # Prefer Entra ID (AAD) auth over admin keys.
  # Note: this argument is supported in newer azurerm versions.
  local_authentication_enabled = var.local_authentication_enabled

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "search" {
  name                = "pe-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = azurerm_search_service.search.id
    subresource_names              = ["searchService"]
    is_manual_connection           = false
  }

  # DNS zone groups are configured manually for this repository.
  # private_dns_zone_group {
  #   name                 = "pdzg-${var.name}"
  #   private_dns_zone_ids = var.private_dns_zone_ids
  # }

  tags = var.tags
}
