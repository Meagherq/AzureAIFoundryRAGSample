terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
  }
}

resource "azapi_resource" "search_kb_connection" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-10-01-preview"
  name      = var.knowledge_base_name
  parent_id = var.project_id
  body = {
    properties = {
      category      = "CognitiveSearch"
      target        = "https://${var.search_service_name}.search.windows.net"
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.search_service_id
      }
    }
  }
}

locals {
  agent_definition_template_path = var.agent_definition_template_file != "" ? var.agent_definition_template_file : "${path.module}/agent_definition.yaml.tftpl"
  agent_definition_yaml = templatefile(local.agent_definition_template_path, {
    agent_name            = var.name
    model_deployment      = var.model_deployment_name
    project_connection_id = azapi_resource.search_kb_connection.id
    search_index_name     = var.search_index_name
  })
  agent_payload_json = jsonencode(yamldecode(local.agent_definition_yaml))
}

resource "null_resource" "foundry_agent" {
  # Each payload change publishes a new agent version.
  triggers = {
    payload_hash = sha256(local.agent_payload_json)
  }
  provisioner "local-exec" {
    interpreter = ["pwsh", "-Command"]
    command     = <<-EOT
      $base64Json = "${base64encode(local.agent_payload_json)}"

      $json = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($base64Json))
      $json | Out-File -FilePath "agent_payload.json" -Encoding UTF8
      
      Write-Host "Agent payload:"
      Get-Content "agent_payload.json"
      Write-Host ""
      $url = "${var.project_endpoints["AI Foundry API"]}/agents/${var.name}/versions?api-version=v1"
      Write-Host "Deploying agent to: $url"
      
      $response = az rest --method post `
        --url $url `
        --resource "https://ai.azure.com" `
        --headers "Content-Type=application/json" `
        --body "@agent_payload.json" 2>&1
      
      Write-Host "Response:"
      Write-Host $response

      Remove-Item "agent_payload.json"
      
      if ($LASTEXITCODE -ne 0) {
        Write-Error "Agent deployment failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
      }
    EOT
  }
}

