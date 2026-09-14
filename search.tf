resource "azurerm_search_service" "this" {
  name                = local.search_service_name
  resource_group_name = azurerm_resource_group.this.name
  location            = coalesce(var.search_location, azurerm_resource_group.this.location)
  sku                 = var.search_sku

  replica_count   = var.search_replica_count
  partition_count = var.search_partition_count

  public_network_access_enabled = var.enable_private_networking ? false : var.search_public_network_access_enabled
  local_authentication_enabled  = false

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}
