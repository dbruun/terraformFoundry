#############################
# Azure Cosmos DB (optional)
#
# Deployed only when var.enable_cosmos_db = true.
#############################

resource "azurerm_cosmosdb_account" "this" {
  count = var.enable_cosmos_db ? 1 : 0

  name                = local.cosmos_db_account_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  public_network_access_enabled = var.enable_private_networking ? false : var.cosmos_db_public_network_access_enabled

  consistency_policy {
    consistency_level       = var.cosmos_db_consistency_level
    max_interval_in_seconds = var.cosmos_db_consistency_level == "BoundedStaleness" ? var.cosmos_db_max_interval_in_seconds : null
    max_staleness_prefix    = var.cosmos_db_consistency_level == "BoundedStaleness" ? var.cosmos_db_max_staleness_prefix : null
  }

  geo_location {
    location          = azurerm_resource_group.this.location
    failover_priority = 0
  }

  tags = local.tags
}
