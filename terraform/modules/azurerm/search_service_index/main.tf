terraform {
  required_version = ">= 1.3"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  endpoint    = "https://${var.search_service_name}.search.windows.net"
  rest_script = "${path.module}/../../../scripts/az_rest.sh"
  script_hash = filesha256(local.rest_script)
  datasource = {
    name = var.datasource_name
    type = "azureblob"
    credentials = {
      connectionString = "ResourceId=/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Storage/storageAccounts/${var.storage_account_name};"
    }
    container = {
      name = var.blob_container_name
    }
  }
  index = {
    name = var.index_name
    fields = concat([
      {
        name       = "id"
        type       = "Edm.String"
        key        = true
        filterable = true
        searchable = true
        analyzer   = "keyword"
      },
      {
        name       = "parent_id"
        type       = "Edm.String"
        key        = false
        filterable = true
        searchable = true
        analyzer   = "keyword"
      },
      {
        name       = "content"
        type       = "Edm.String"
        searchable = true
        analyzer   = "en.lucene"
      }
      ], [
      for field in [
        { name = "blob_url", type = "Edm.String", searchable = false, sortable = true, facetable = false, analyzer = null },
        { name = "metadata_storage_path", type = "Edm.String", searchable = true, sortable = true, facetable = false, analyzer = "standard.lucene" },
        { name = "metadata_storage_name", type = "Edm.String", searchable = true, sortable = true, facetable = false, analyzer = "keyword" },
        { name = "metadata_storage_last_modified", type = "Edm.DateTimeOffset", searchable = false, sortable = true, facetable = false, analyzer = null },
        { name = "metadata_storage_size", type = "Edm.Int64", searchable = false, sortable = true, facetable = false, analyzer = null },
        { name = "invoiceNo", type = "Edm.String", searchable = true, sortable = false, facetable = true, analyzer = "standard.lucene" },
        { name = "customerId", type = "Edm.String", searchable = true, sortable = false, facetable = true, analyzer = "standard.lucene" }
        ] : merge({
          name        = field.name
          type        = field.type
          searchable  = field.searchable
          filterable  = true
          retrievable = true
          sortable    = field.sortable
          facetable   = field.facetable
          key         = false
          synonymMaps = []
      }, field.analyzer == null ? {} : { analyzer = field.analyzer })
    ])
    suggesters = [{
      name         = "sg"
      searchMode   = "analyzingInfixMatching"
      sourceFields = ["content"]
    }]
  }
  skillset = {
    name = var.skillset_name
    skills = [{
      "@odata.type"     = "#Microsoft.Skills.Text.SplitSkill"
      context           = "/document"
      textSplitMode     = "pages"
      maximumPageLength = 2000
      pageOverlapLength = 500
      inputs            = [{ name = "text", source = "/document/content" }]
      outputs           = [{ name = "textItems", targetName = "pages" }]
    }]
    indexProjections = {
      selectors = [{
        targetIndexName    = var.index_name
        parentKeyFieldName = "parent_id"
        sourceContext      = "/document/pages/*"
        mappings = [
          { name = "content", source = "/document/pages/*" },
          { name = "blob_url", source = "/document/metadata_storage_path" },
          { name = "metadata_storage_path", source = "/document/metadata_storage_path" },
          { name = "metadata_storage_name", source = "/document/metadata_storage_name" },
          { name = "metadata_storage_last_modified", source = "/document/metadata_storage_last_modified" },
          { name = "metadata_storage_size", source = "/document/metadata_storage_size" }
        ]
      }]
      parameters = {
        projectionMode = "skipIndexingParentDocuments"
      }
    }
  }
  indexer = {
    name            = var.indexer_name
    dataSourceName  = var.datasource_name
    targetIndexName = var.index_name
    skillsetName    = var.skillset_name
    schedule        = { interval = "P1D" }
    parameters      = { configuration = { dataToExtract = "contentAndMetadata" } }
    fieldMappings = [{
      sourceFieldName = "metadata_storage_path"
      targetFieldName = "blob_url"
    }]
  }
}

resource "null_resource" "datasource" {
  triggers = {
    url          = "${local.endpoint}/datasources/${var.datasource_name}?api-version=${var.search_api_version}"
    payload_hash = sha256(jsonencode(local.datasource))
    script_hash  = local.script_hash
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "bash \"$REST_SCRIPT\""
    environment = {
      REST_SCRIPT         = local.rest_script
      REST_METHOD         = "put"
      REST_URL            = self.triggers.url
      REST_RESOURCE       = "https://search.azure.com"
      REST_PAYLOAD_BASE64 = base64encode(jsonencode(local.datasource))
    }
  }
}

resource "null_resource" "index" {
  triggers = {
    url          = "${local.endpoint}/indexes/${var.index_name}?api-version=${var.search_api_version}"
    payload_hash = sha256(jsonencode(local.index))
    script_hash  = local.script_hash
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "bash \"$REST_SCRIPT\""
    environment = {
      REST_SCRIPT         = local.rest_script
      REST_METHOD         = "put"
      REST_URL            = self.triggers.url
      REST_RESOURCE       = "https://search.azure.com"
      REST_PAYLOAD_BASE64 = base64encode(jsonencode(local.index))
    }
  }

  depends_on = [null_resource.datasource]
}

resource "null_resource" "skillset" {
  triggers = {
    url          = "${local.endpoint}/skillsets/${var.skillset_name}?api-version=${var.search_api_version}"
    payload_hash = sha256(jsonencode(local.skillset))
    script_hash  = local.script_hash
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "bash \"$REST_SCRIPT\""
    environment = {
      REST_SCRIPT         = local.rest_script
      REST_METHOD         = "put"
      REST_URL            = self.triggers.url
      REST_RESOURCE       = "https://search.azure.com"
      REST_PAYLOAD_BASE64 = base64encode(jsonencode(local.skillset))
    }
  }

  depends_on = [null_resource.datasource, null_resource.index]
}

resource "null_resource" "indexer" {
  triggers = {
    url          = "${local.endpoint}/indexers/${var.indexer_name}?api-version=${var.search_api_version}"
    payload_hash = sha256(jsonencode(local.indexer))
    script_hash  = local.script_hash
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "bash \"$REST_SCRIPT\""
    environment = {
      REST_SCRIPT         = local.rest_script
      REST_METHOD         = "put"
      REST_URL            = self.triggers.url
      REST_RESOURCE       = "https://search.azure.com"
      REST_PAYLOAD_BASE64 = base64encode(jsonencode(local.indexer))
    }
  }

  depends_on = [null_resource.datasource, null_resource.index, null_resource.skillset]
}
