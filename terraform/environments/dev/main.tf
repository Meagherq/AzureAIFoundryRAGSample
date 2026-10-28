terraform {
  required_version = ">= 1.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  # Local state by default. For remote state, add a backend.tf (see README); CI generates one.
}

provider "azurerm" {
  storage_use_azuread = true
  subscription_id     = var.subscription_id
  features {}
}

# provider "azurerm" {
#   alias               = "private_dns"
#   subscription_id     = var.private_dns_subscription_id
#   storage_use_azuread = true
#   features {}
# }

provider "http" {}

provider "azapi" {}

# Generate random suffix for uniqueness
resource "random_string" "suffix" {
  length  = 3
  special = false
  upper   = false
}

locals {
  suffix = random_string.suffix.result
  tags = merge(
    var.tags,
    {
      Environment = var.environment_prefix
      ManagedBy   = "Terraform"
    }
  )
}

module "project" {
  source = "../../project"

  providers = {
    azurerm = azurerm
    # azurerm.private_dns = azurerm.private_dns
  }

  environment_prefix                    = var.environment_prefix
  subscription_id                       = var.subscription_id
  suffix                                = local.suffix
  tags                                  = local.tags
  location                              = var.location
  data_location                         = var.data_location
  workload                              = var.workload
  existing_resource_group_name          = var.existing_resource_group_name
  enable_rbac                           = var.enable_rbac
  enable_private_networking             = var.enable_private_networking
  sharepoint_connections                = var.sharepoint_connections
  enable_m365_public_endpoint           = var.enable_m365_public_endpoint
  m365_authorization_scheme             = var.m365_authorization_scheme
  existing_network_resource_group_name  = var.existing_network_resource_group_name
  existing_vnet_name                    = var.existing_vnet_name
  existing_private_endpoint_subnet_name = var.existing_private_endpoint_subnet_name
  existing_agent_subnet_name            = var.existing_agent_subnet_name
  # existing_private_dns_zone_resource_group_name = var.existing_private_dns_zone_resource_group_name
  agent_definition_template_file = var.agent_definition_template_file
  openai_deployment_name         = var.openai_deployment_name
  openai_model_name              = var.openai_model_name
  openai_model_version           = var.openai_model_version
  openai_model_sku_name          = var.openai_model_sku_name
  openai_model_sku_capacity      = var.openai_model_sku_capacity
}
