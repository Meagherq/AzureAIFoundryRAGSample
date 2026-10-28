variable "name" {
  description = "The name suffix for the project"
  type        = string
}

variable "location" {
  description = "The Azure location where the resources should exist"
  type        = string
}

variable "cognitive_account_id" {
  description = "The ID of the Cognitive Account"
  type        = string
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

variable "description" {
  description = "The description of the cognitive project"
  type        = string
  default     = "Example Description"
}

variable "display_name" {
  description = "The display name of the cognitive project"
  type        = string
  default     = "Example Project"
}