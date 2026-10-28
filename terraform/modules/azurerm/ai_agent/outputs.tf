output "id" {
  value = azapi_resource.search_kb_connection.id
}

output "name" {
  value = azapi_resource.search_kb_connection.name
}

output "sharepoint_connection_ids" {
  description = "SharePoint project connection IDs keyed by connection name."
  value       = local.sharepoint_connection_ids
}

output "activity_protocol_endpoint" {
  description = "Agent Activity Protocol URL for Azure Bot Service. Publishing and channel registration are separate steps."
  value       = "${trimsuffix(var.project_endpoints["AI Foundry API"], "/")}/agents/${var.name}/endpoint/protocols/activityprotocol"
  depends_on  = [null_resource.agent_endpoint]
}
