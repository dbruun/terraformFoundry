resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = true
}

locals {
  resource_group_name = coalesce(var.resource_group_name, "${var.name_prefix}-rg")

  foundry_account_name          = coalesce(var.foundry_account_name, "${var.name_prefix}-foundry")
  foundry_custom_subdomain_name = coalesce(var.foundry_custom_subdomain_name, "${var.name_prefix}-foundry-${random_string.suffix.result}")

  search_service_name = coalesce(var.search_service_name, "${var.name_prefix}search${random_string.suffix.result}")

  cosmos_db_account_name = coalesce(var.cosmos_db_account_name, "${var.name_prefix}-cosmos-${random_string.suffix.result}")

  # GUID of the built-in Cosmos DB SQL role "Cosmos DB Built-in Data Contributor", which
  # grants full data-plane (CRUD) access. This ID is fixed by Azure for all Cosmos DB accounts.
  # See: https://learn.microsoft.com/azure/cosmos-db/how-to-setup-rbac#built-in-role-definitions
  cosmos_db_data_contributor_role_id = "00000000-0000-0000-0000-000000000002"

  tags = var.tags
}
