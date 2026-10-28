output "resource_group_id" {
  description = "The ID of the resource group"
  value       = data.azurerm_resource_group.existing_resource_group.id
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = data.azurerm_resource_group.existing_resource_group.name
}

output "resource_group_location" {
  description = "The location of the resource group"
  value       = data.azurerm_resource_group.existing_resource_group.location
}

output "search_service_id" {
  description = "The ID of the Azure AI Search service"
  value       = module.search_service.id
}

output "search_service_name" {
  description = "The name of the Azure AI Search service"
  value       = module.search_service.name
}

output "search_service_endpoint" {
  description = "The endpoint of the Azure AI Search service"
  value       = module.search_service.endpoint
}

output "cognitive_service_endpoint" {
  description = "The endpoint of the Cognitive Services Account"
  value       = module.cognitive.endpoint
}

output "project_endpoints" {
  description = "The endpoints of the Azure AI Foundry Project"
  value       = module.cognitive_project.endpoints
}

output "sharepoint_connection_ids" {
  description = "SharePoint project connection IDs keyed by connection name."
  value       = module.ai_agent.sharepoint_connection_ids
}

output "activity_protocol_endpoint" {
  description = "Agent Activity Protocol URL for Azure Bot Service."
  value       = module.ai_agent.activity_protocol_endpoint
}
