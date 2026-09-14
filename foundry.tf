#############################
# Azure AI Foundry (Cognitive Services "AIServices" account + project)
#############################

resource "azurerm_cognitive_account" "foundry" {
  name                = local.foundry_account_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  kind     = "AIServices"
  sku_name = var.foundry_sku_name

  custom_subdomain_name      = local.foundry_custom_subdomain_name
  project_management_enabled = true

  public_network_access_enabled = var.enable_private_networking ? false : var.foundry_public_network_access_enabled
  local_auth_enabled            = false

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_cognitive_account_project" "default" {
  name                 = var.foundry_project_name
  cognitive_account_id = azurerm_cognitive_account.foundry.id
  location             = azurerm_resource_group.this.location
  display_name         = var.foundry_project_name
  description          = "Default Azure AI Foundry project"

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

# Grant the Foundry account's managed identity access to Azure AI Search so it can be
# used as a connected resource (e.g. for Agent Service / RAG tool grounding).
resource "azurerm_role_assignment" "foundry_to_search_service_contributor" {
  scope                = azurerm_search_service.this.id
  role_definition_name = "Search Service Contributor"
  principal_id         = azurerm_cognitive_account.foundry.identity[0].principal_id
}

resource "azurerm_role_assignment" "foundry_to_search_index_data_contributor" {
  scope                = azurerm_search_service.this.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azurerm_cognitive_account.foundry.identity[0].principal_id
}

resource "azurerm_cognitive_account_connection_entra_id" "search" {
  name                 = "${local.search_service_name}-connection"
  cognitive_account_id = azurerm_cognitive_account.foundry.id
  category             = "CognitiveSearch"
  target               = "https://${azurerm_search_service.this.name}.search.windows.net"

  metadata = {
    ApiType    = "Azure"
    ResourceId = azurerm_search_service.this.id
    Location   = azurerm_search_service.this.location
  }

  depends_on = [
    azurerm_role_assignment.foundry_to_search_service_contributor,
    azurerm_role_assignment.foundry_to_search_index_data_contributor,
  ]
}

# Grant the Foundry account's managed identity data-plane access to Cosmos DB and
# wire it up as a connected resource, only when Cosmos DB is enabled.
resource "azurerm_cosmosdb_sql_role_assignment" "foundry_data_contributor" {
  count = var.enable_cosmos_db ? 1 : 0

  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this[0].name
  role_definition_id  = "${azurerm_cosmosdb_account.this[0].id}/sqlRoleDefinitions/${local.cosmos_db_data_contributor_role_id}"
  principal_id        = azurerm_cognitive_account.foundry.identity[0].principal_id
  scope               = azurerm_cosmosdb_account.this[0].id
}

resource "azurerm_cognitive_account_connection_entra_id" "cosmosdb" {
  count = var.enable_cosmos_db ? 1 : 0

  name                 = "${local.cosmos_db_account_name}-connection"
  cognitive_account_id = azurerm_cognitive_account.foundry.id
  category             = "CosmosDb"
  target               = azurerm_cosmosdb_account.this[0].endpoint

  metadata = {
    ResourceId = azurerm_cosmosdb_account.this[0].id
  }

  depends_on = [azurerm_cosmosdb_sql_role_assignment.foundry_data_contributor]
}
