terraform {
  required_version = ">= 1.3"

  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
    null = {
      source = "hashicorp/null"
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

resource "azapi_resource" "sharepoint_connection" {
  for_each = var.sharepoint_connections

  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-10-01-preview"
  name      = each.key
  parent_id = var.project_id
  body = {
    properties = {
      category      = "CustomKeys"
      authType      = "CustomKeys"
      target        = "_"
      isSharedToAll = each.value.is_shared_to_all
      credentials = {
        keys = {
          siteUrl = each.value.site_url
        }
      }
      metadata = {
        type = "sharepoint_grounding"
      }
    }
  }

  lifecycle {
    precondition {
      condition     = each.key != var.knowledge_base_name
      error_message = "A SharePoint connection cannot have the same name as the search connection."
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
  agent_definition   = yamldecode(local.agent_definition_yaml)
  agent_payload_json = jsonencode(local.agent_payload)
  sharepoint_connection_ids = {
    for name, connection in azapi_resource.sharepoint_connection : name => connection.id
  }
  sharepoint_tools = length(var.sharepoint_connections) == 0 ? [] : [{
    type = "sharepoint_grounding_preview"
    sharepoint_grounding_preview = {
      project_connections = [
        for name in sort(keys(var.sharepoint_connections)) : {
          project_connection_id = local.sharepoint_connection_ids[name]
        }
      ]
    }
  }]
  # Append here so custom YAML templates receive the same SharePoint configuration.
  agent_payload = merge(local.agent_definition, {
    definition = merge(local.agent_definition.definition, {
      tools = concat(
        local.agent_definition.definition.tools,
        local.sharepoint_tools
      )
    })
  })
}

resource "null_resource" "foundry_agent" {
  # Each payload change publishes a new agent version.
  triggers = {
    payload_hash     = sha256(local.agent_payload_json)
    project_endpoint = var.project_endpoints["AI Foundry API"]
    agent_name       = var.name
    script_hash      = filesha256("${path.module}/../../../scripts/az_rest.sh")
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "bash \"$REST_SCRIPT\""
    environment = {
      REST_SCRIPT         = "${path.module}/../../../scripts/az_rest.sh"
      REST_METHOD         = "post"
      REST_URL            = "${trimsuffix(var.project_endpoints["AI Foundry API"], "/")}/agents/${replace(urlencode(var.name), "+", "%20")}/versions?api-version=v1"
      REST_RESOURCE       = "https://ai.azure.com"
      REST_PAYLOAD_BASE64 = base64encode(local.agent_payload_json)
    }
  }

  lifecycle {
    precondition {
      condition = length(var.sharepoint_connections) == 0 || alltrue([
        for tool in local.agent_definition.definition.tools : tool.type != "sharepoint_grounding_preview"
      ])
      error_message = "When sharepoint_connections is configured, remove SharePoint tools from the YAML template; the module appends the single supported SharePoint tool."
    }
  }
}

resource "null_resource" "agent_endpoint" {
  triggers = {
    agent_deployment            = null_resource.foundry_agent.id
    project_endpoint            = var.project_endpoints["AI Foundry API"]
    agent_name                  = var.name
    enable_m365_public_endpoint = tostring(var.enable_m365_public_endpoint)
    authorization_scheme        = var.m365_authorization_scheme
    script_hash                 = filesha256("${path.module}/configure_agent_endpoint.sh")
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "bash \"$ENDPOINT_SCRIPT\""
    environment = {
      ENDPOINT_SCRIPT             = "${path.module}/configure_agent_endpoint.sh"
      FOUNDRY_PROJECT_ENDPOINT    = self.triggers.project_endpoint
      FOUNDRY_AGENT_NAME          = self.triggers.agent_name
      ENABLE_M365_PUBLIC_ENDPOINT = self.triggers.enable_m365_public_endpoint
      M365_AUTHORIZATION_SCHEME   = self.triggers.authorization_scheme
    }
  }
}
