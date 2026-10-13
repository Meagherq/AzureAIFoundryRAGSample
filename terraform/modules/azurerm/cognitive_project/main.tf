resource "azurerm_cognitive_account_project" "project" {
  name                 = "cog-proj-${var.name}"
  cognitive_account_id = var.cognitive_account_id
  location             = var.location
  description          = var.description
  display_name         = var.display_name

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
