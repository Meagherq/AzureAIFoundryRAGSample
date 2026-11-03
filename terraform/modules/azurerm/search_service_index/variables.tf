
variable "resource_group_name" {
  type = string

  validation {
    condition     = can(regex("^[^/[:space:]][^/]*$", var.resource_group_name))
    error_message = "resource_group_name must be a nonempty resource group name, not a resource ID."
  }
}
variable "location" {
  type = string
}
variable "search_service_name" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9]{2}([a-z0-9-]{0,57}[a-z0-9])?$", var.search_service_name)) && length(regexall("--", var.search_service_name)) == 0
    error_message = "search_service_name must be a 2-60 character lowercase Search service name, not a URL. The first, second, and last characters must be alphanumeric, with no consecutive hyphens."
  }
}

variable "storage_account_name" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase alphanumeric characters."
  }
}
variable "blob_container_name" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.blob_container_name)) && length(regexall("--", var.blob_container_name)) == 0
    error_message = "blob_container_name must be 3-63 lowercase alphanumeric or hyphen characters, without leading, trailing, or consecutive hyphens."
  }
}

# Logical names
variable "datasource_name" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,126}[a-z0-9]$|^[a-z0-9]$", var.datasource_name))
    error_message = "datasource_name must be 1-128 lowercase alphanumeric or hyphen characters, starting and ending with an alphanumeric character."
  }
}
variable "index_name" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_-]{1,127}$", var.index_name)) && length(regexall("--|__", var.index_name)) == 0
    error_message = "index_name must be 2-128 lowercase alphanumeric, underscore or hyphen characters, starting with an alphanumeric character and without consecutive hyphens or underscores."
  }
}
variable "skillset_name" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,126}[a-z0-9]$|^[a-z0-9]$", var.skillset_name))
    error_message = "skillset_name must be 1-128 lowercase alphanumeric or hyphen characters, starting and ending with an alphanumeric character."
  }
}
variable "indexer_name" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,126}[a-z0-9]$|^[a-z0-9]$", var.indexer_name))
    error_message = "indexer_name must be 1-128 lowercase alphanumeric or hyphen characters, starting and ending with an alphanumeric character."
  }
}

# API version (keep current)
variable "search_api_version" {
  type    = string
  default = "2024-07-01"

  validation {
    condition     = can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}(-preview)?$", var.search_api_version))
    error_message = "search_api_version must be an Azure API version such as 2024-07-01."
  }
}
