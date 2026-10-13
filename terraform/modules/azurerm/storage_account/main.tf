resource "azurerm_storage_account" "storage" {
  name                             = var.name
  location                         = var.location
  resource_group_name              = var.resource_group_name
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  shared_access_key_enabled        = false
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = true
  tags                             = var.tags
}

resource "azurerm_storage_container" "container" {
  for_each = var.containers

  name                  = each.key
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = each.value.access_type
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${var.name}-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.name}-blob"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  # DNS zone groups are configured manually for this repository.
  # private_dns_zone_group {
  #   name                 = "pdzg-${var.name}-blob"
  #   private_dns_zone_ids = var.private_dns_zone_ids
  # }

  tags = var.tags
}