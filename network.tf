#############################
# Optional VNet + Private Endpoints
#
# Created only when var.enable_private_networking = true.
#
# NOTE: vnet_address_space must contain both subnets created below; this is
# validated implicitly by Azure at apply time (azurerm_subnet requires its
# prefixes to fall within the parent virtual network's address space).
#############################

locals {
  # Convert each IPv4 CIDR block into its [start, end] address range (as integers)
  # so that overlap between the private endpoint and agent subnets can be detected,
  # even when their prefixes differ (e.g. "10.60.1.0/24" vs "10.60.1.128/25").
  private_endpoint_subnet_ranges = [
    for cidr in var.private_endpoint_subnet_address_prefixes : {
      start = local.cidr_start_address[cidr]
      end   = local.cidr_start_address[cidr] + pow(2, 32 - tonumber(split("/", cidr)[1])) - 1
    }
  ]

  agent_subnet_ranges = [
    for cidr in var.agent_subnet_address_prefixes : {
      start = local.cidr_start_address[cidr]
      end   = local.cidr_start_address[cidr] + pow(2, 32 - tonumber(split("/", cidr)[1])) - 1
    }
  ]

  cidr_start_address = {
    for cidr in setunion(var.private_endpoint_subnet_address_prefixes, var.agent_subnet_address_prefixes) :
    cidr => sum([
      for i, octet in split(".", cidrhost(cidr, 0)) : tonumber(octet) * pow(256, 3 - i)
    ])
  }
}

check "subnet_cidrs_do_not_overlap" {
  assert {
    condition = !var.enable_private_networking || alltrue([
      for pe in local.private_endpoint_subnet_ranges : alltrue([
        for agent in local.agent_subnet_ranges : pe.end < agent.start || agent.end < pe.start
      ])
    ])
    error_message = "private_endpoint_subnet_address_prefixes and agent_subnet_address_prefixes must not overlap."
  }
}

resource "azurerm_virtual_network" "this" {
  count = var.enable_private_networking ? 1 : 0

  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.vnet_address_space
  tags                = local.tags
}

resource "azurerm_subnet" "private_endpoints" {
  count = var.enable_private_networking ? 1 : 0

  name                 = "${var.name_prefix}-pe-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this[0].name
  address_prefixes     = var.private_endpoint_subnet_address_prefixes

  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "agent" {
  count = var.enable_private_networking ? 1 : 0

  name                 = "${var.name_prefix}-agent-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this[0].name
  address_prefixes     = var.agent_subnet_address_prefixes

  delegation {
    name = "foundry-agent-delegation"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Private DNS zones required to resolve the private endpoints created below.
resource "azurerm_private_dns_zone" "cognitiveservices" {
  count = var.enable_private_networking ? 1 : 0

  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone" "search" {
  count = var.enable_private_networking ? 1 : 0

  name                = "privatelink.search.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone" "cosmosdb" {
  count = var.enable_private_networking && var.enable_cosmos_db ? 1 : 0

  name                = "privatelink.documents.azure.com"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "cognitiveservices" {
  count = var.enable_private_networking ? 1 : 0

  name                  = "${var.name_prefix}-cognitiveservices-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.cognitiveservices[0].name
  virtual_network_id    = azurerm_virtual_network.this[0].id
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "search" {
  count = var.enable_private_networking ? 1 : 0

  name                  = "${var.name_prefix}-search-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.search[0].name
  virtual_network_id    = azurerm_virtual_network.this[0].id
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmosdb" {
  count = var.enable_private_networking && var.enable_cosmos_db ? 1 : 0

  name                  = "${var.name_prefix}-cosmosdb-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.cosmosdb[0].name
  virtual_network_id    = azurerm_virtual_network.this[0].id
  tags                  = local.tags
}

# Private Endpoint for the Foundry (Cognitive Services AIServices) account.
resource "azurerm_private_endpoint" "foundry" {
  count = var.enable_private_networking ? 1 : 0

  name                = "${local.foundry_account_name}-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints[0].id
  tags                = local.tags

  private_service_connection {
    name                           = "${local.foundry_account_name}-psc"
    private_connection_resource_id = azurerm_cognitive_account.foundry.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.cognitiveservices[0].id]
  }
}

# Private Endpoint for Azure AI Search.
resource "azurerm_private_endpoint" "search" {
  count = var.enable_private_networking ? 1 : 0

  name                = "${local.search_service_name}-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints[0].id
  tags                = local.tags

  private_service_connection {
    name                           = "${local.search_service_name}-psc"
    private_connection_resource_id = azurerm_search_service.this.id
    subresource_names              = ["searchService"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.search[0].id]
  }
}

# Private Endpoint for Cosmos DB, only created when both private networking and Cosmos DB are enabled.
resource "azurerm_private_endpoint" "cosmosdb" {
  count = var.enable_private_networking && var.enable_cosmos_db ? 1 : 0

  name                = "${local.cosmos_db_account_name}-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints[0].id
  tags                = local.tags

  private_service_connection {
    name                           = "${local.cosmos_db_account_name}-psc"
    private_connection_resource_id = azurerm_cosmosdb_account.this[0].id
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.cosmosdb[0].id]
  }
}
