variable "name" {
  description = "The name of the Key Vault"
  type        = string
}

variable "location" {
  description = "The Azure location where the resource should exist"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group"
  type        = string
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

variable "private_endpoint_subnet_id" {
  description = "The ID of the externally managed subnet for the private endpoint."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "The IDs of the externally managed Private DNS Zones used when the DNS zone group is configured manually."
  type        = list(string)
}
