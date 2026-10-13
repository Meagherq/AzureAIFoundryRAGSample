data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "vault" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = var.tags

  purge_protection_enabled   = true
  rbac_authorization_enabled = true
}

resource "azurerm_private_endpoint" "vault" {
  name                = "pe-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = azurerm_key_vault.vault.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  # DNS zone groups are configured manually for this repository.
  # private_dns_zone_group {
  #   name                 = "pdzg-${var.name}"
  #   private_dns_zone_ids = var.private_dns_zone_ids
  # }

  tags = var.tags
}
