variable "name_prefix" {
  description = "Prefix used when naming all resources created by this configuration."
  type        = string
  default     = "foundry"

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.name_prefix))
    error_message = "name_prefix must be 2-10 characters long and contain only lowercase letters and numbers."
  }
}

variable "location" {
  description = "Azure region in which to deploy all resources."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Name of the resource group to create for the Foundry deployment."
  type        = string
  default     = null
}

variable "tags" {
  description = "A mapping of tags to apply to all resources that support tagging."
  type        = map(string)
  default     = {}
}

#############################
# Azure AI Foundry (Cognitive Services "AIServices" account)
#############################

variable "foundry_account_name" {
  description = "Name of the Azure AI Foundry (Cognitive Services AIServices) account. Defaults to '<name_prefix>-foundry' when not set."
  type        = string
  default     = null
}

variable "foundry_sku_name" {
  description = "SKU used for the Azure AI Foundry account."
  type        = string
  default     = "S0"
}

variable "foundry_custom_subdomain_name" {
  description = "Custom subdomain name for the Foundry account. Required for Entra ID authentication and to attach a Private Endpoint. Defaults to '<name_prefix>-foundry-<random>' when not set."
  type        = string
  default     = null
}

variable "foundry_project_name" {
  description = "Name of the default Azure AI Foundry project created inside the Foundry account."
  type        = string
  default     = "default-project"
}

variable "foundry_public_network_access_enabled" {
  description = "Whether public network access is allowed for the Foundry account. Set to false when using private networking."
  type        = bool
  default     = true
}

#############################
# Azure AI Search (required component)
#############################

variable "search_service_name" {
  description = "Name of the Azure AI Search service. Defaults to '<name_prefix>search<random>' when not set."
  type        = string
  default     = null
}

variable "search_location" {
  description = "Azure region for Azure AI Search. Defaults to the resource group region when not set."
  type        = string
  default     = null
}

variable "search_sku" {
  description = "SKU of the Azure AI Search service."
  type        = string
  default     = "standard"
}

variable "search_replica_count" {
  description = "Number of replicas for the Azure AI Search service."
  type        = number
  default     = 1
}

variable "search_partition_count" {
  description = "Number of partitions for the Azure AI Search service."
  type        = number
  default     = 1
}

variable "search_public_network_access_enabled" {
  description = "Whether public network access is allowed for the Azure AI Search service. Set to false when using private networking."
  type        = bool
  default     = true
}

#############################
# Azure Cosmos DB (optional component)
#############################

variable "enable_cosmos_db" {
  description = "Whether to deploy an Azure Cosmos DB account for use with the Foundry account (e.g. for the Agent Service thread storage). Optional."
  type        = bool
  default     = false
}

variable "cosmos_db_account_name" {
  description = "Name of the Cosmos DB account. Defaults to '<name_prefix>-cosmos-<random>' when not set."
  type        = string
  default     = null
}

variable "cosmos_db_consistency_level" {
  description = "The consistency level used by the Cosmos DB account."
  type        = string
  default     = "Session"

  validation {
    condition     = contains(["Strong", "BoundedStaleness", "Session", "ConsistentPrefix", "Eventual"], var.cosmos_db_consistency_level)
    error_message = "cosmos_db_consistency_level must be one of: Strong, BoundedStaleness, Session, ConsistentPrefix, Eventual."
  }
}

variable "cosmos_db_max_interval_in_seconds" {
  description = "The maximum staleness interval, in seconds, used when cosmos_db_consistency_level is 'BoundedStaleness'. Ignored otherwise."
  type        = number
  default     = 5

  validation {
    condition     = var.cosmos_db_max_interval_in_seconds >= 5 && var.cosmos_db_max_interval_in_seconds <= 86400
    error_message = "cosmos_db_max_interval_in_seconds must be between 5 and 86400."
  }
}

variable "cosmos_db_max_staleness_prefix" {
  description = "The maximum number of stale requests tolerated when cosmos_db_consistency_level is 'BoundedStaleness'. Ignored otherwise."
  type        = number
  default     = 100

  validation {
    condition     = var.cosmos_db_max_staleness_prefix >= 10 && var.cosmos_db_max_staleness_prefix <= 2147483647
    error_message = "cosmos_db_max_staleness_prefix must be between 10 and 2147483647."
  }
}

variable "cosmos_db_public_network_access_enabled" {
  description = "Whether public network access is allowed for the Cosmos DB account. Set to false when using private networking."
  type        = bool
  default     = true
}

#############################
# Optional VNet integration / Private Endpoints
#############################

variable "enable_private_networking" {
  description = "Whether to create a virtual network and private endpoints for the Foundry account, Azure AI Search and (when enabled) Cosmos DB. Optional."
  type        = bool
  default     = false
}

variable "vnet_address_space" {
  description = "Address space for the virtual network created when enable_private_networking is true."
  type        = list(string)
  default     = ["10.60.0.0/16"]
}

variable "private_endpoint_subnet_address_prefixes" {
  description = "Address prefixes for the subnet hosting the private endpoints, used when enable_private_networking is true."
  type        = list(string)
  default     = ["10.60.1.0/24"]
}

variable "agent_subnet_address_prefixes" {
  description = "Address prefixes for the subnet delegated to the Foundry Agent network injection, used when enable_private_networking is true."
  type        = list(string)
  default     = ["10.60.2.0/24"]
}
