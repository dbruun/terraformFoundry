output "resource_group_name" {
  description = "Name of the resource group containing the deployed resources."
  value       = azurerm_resource_group.this.name
}

output "foundry_account_id" {
  description = "Resource ID of the Azure AI Foundry (Cognitive Services AIServices) account."
  value       = azurerm_cognitive_account.foundry.id
}

output "foundry_account_name" {
  description = "Name of the Azure AI Foundry account."
  value       = azurerm_cognitive_account.foundry.name
}

output "foundry_endpoint" {
  description = "Endpoint used to connect to the Azure AI Foundry account."
  value       = azurerm_cognitive_account.foundry.endpoint
}

output "foundry_project_id" {
  description = "Resource ID of the default Azure AI Foundry project."
  value       = azurerm_cognitive_account_project.default.id
}

output "search_service_id" {
  description = "Resource ID of the Azure AI Search service."
  value       = azurerm_search_service.this.id
}

output "search_service_name" {
  description = "Name of the Azure AI Search service."
  value       = azurerm_search_service.this.name
}

output "cosmos_db_account_id" {
  description = "Resource ID of the Cosmos DB account, when enabled."
  value       = var.enable_cosmos_db ? azurerm_cosmosdb_account.this[0].id : null
}

output "cosmos_db_endpoint" {
  description = "Endpoint of the Cosmos DB account, when enabled."
  value       = var.enable_cosmos_db ? azurerm_cosmosdb_account.this[0].endpoint : null
}

output "virtual_network_id" {
  description = "Resource ID of the virtual network created for private networking, when enabled."
  value       = var.enable_private_networking ? azurerm_virtual_network.this[0].id : null
}

output "private_endpoint_subnet_id" {
  description = "Resource ID of the subnet hosting private endpoints, when private networking is enabled."
  value       = var.enable_private_networking ? azurerm_subnet.private_endpoints[0].id : null
}

output "agent_subnet_id" {
  description = "Resource ID of the subnet delegated for Foundry Agent network injection, when private networking is enabled."
  value       = var.enable_private_networking ? azurerm_subnet.agent[0].id : null
}
