# terraformFoundry

Terraform configuration to deploy [Microsoft (Azure AI) Foundry](https://learn.microsoft.com/azure/ai-foundry/) in Azure,
together with its commonly used supporting components:

- **Azure AI Foundry account** — deployed as a Cognitive Services account with `kind = "AIServices"`
  (the modern, unified Foundry resource), including a default Foundry project.
- **Azure AI Search** — deployed and connected to the Foundry account (required).
- **Azure Cosmos DB** — deployed and connected to the Foundry account (**optional**, e.g. for Agent Service
  thread storage), controlled by `enable_cosmos_db`.
- **VNet integration & Private Endpoints** — an **optional** virtual network with private endpoints for the
  Foundry account, Azure AI Search, and Cosmos DB (when enabled), controlled by `enable_private_networking`.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm provider | ~> 4.0 |

You must be authenticated to Azure (e.g. via `az login`) or have the appropriate environment
variables set for the `azurerm` provider before running `terraform plan`/`apply`.

## Usage

```hcl
module "foundry" {
  source = "./" # or a git/registry reference if you vendor this repo as a module

  name_prefix = "myfoundry"
  location    = "eastus2"

  # Optional: deploy Cosmos DB alongside the Foundry account
  enable_cosmos_db = true

  # Optional: deploy a VNet and private endpoints, and disable public network access
  enable_private_networking = true
}
```

Or, to deploy directly from the root of this repository:

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars as needed

terraform init
terraform plan
terraform apply
```

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `name_prefix` | Prefix used when naming all resources. | `"foundry"` |
| `location` | Azure region to deploy into. | `"eastus2"` |
| `resource_group_name` | Name of the resource group to create. | `<name_prefix>-rg` |
| `tags` | Tags applied to all taggable resources. | `{}` |
| `foundry_account_name` | Name of the Foundry (Cognitive Services `AIServices`) account. | `<name_prefix>-foundry` |
| `foundry_sku_name` | SKU for the Foundry account. | `"S0"` |
| `foundry_project_name` | Name of the default Foundry project. | `"default-project"` |
| `foundry_public_network_access_enabled` | Allow public network access to the Foundry account (ignored, forced to `false`, when private networking is enabled). | `true` |
| `search_service_name` | Name of the Azure AI Search service. | `<name_prefix>search<random>` |
| `search_location` | Azure region for Azure AI Search; override if the primary region lacks capacity. Cross-region deployment may incur latency and data-transfer costs. | Resource group region |
| `search_sku` | SKU for Azure AI Search. | `"standard"` |
| `search_replica_count` | Replica count for Azure AI Search. | `1` |
| `search_partition_count` | Partition count for Azure AI Search. | `1` |
| `search_public_network_access_enabled` | Allow public network access to Azure AI Search (ignored, forced to `false`, when private networking is enabled). | `true` |
| `enable_cosmos_db` | **Optional.** Deploy a Cosmos DB account and connect it to the Foundry account. | `false` |
| `cosmos_db_account_name` | Name of the Cosmos DB account. | `<name_prefix>-cosmos-<random>` |
| `cosmos_db_consistency_level` | Consistency level for the Cosmos DB account. | `"Session"` |
| `cosmos_db_max_interval_in_seconds` | Max staleness interval (seconds), used only when consistency level is `BoundedStaleness`. | `5` |
| `cosmos_db_max_staleness_prefix` | Max staleness prefix, used only when consistency level is `BoundedStaleness`. | `100` |
| `cosmos_db_public_network_access_enabled` | Allow public network access to Cosmos DB (ignored, forced to `false`, when private networking is enabled). | `true` |
| `enable_private_networking` | **Optional.** Create a VNet and private endpoints for the Foundry account, Azure AI Search and Cosmos DB (when enabled). | `false` |
| `vnet_address_space` | Address space for the created VNet. | `["10.60.0.0/16"]` |
| `private_endpoint_subnet_address_prefixes` | Address prefixes for the private endpoint subnet. | `["10.60.1.0/24"]` |
| `agent_subnet_address_prefixes` | Address prefixes for the subnet delegated to Foundry Agent network injection. | `["10.60.2.0/24"]` |

## Outputs

| Name | Description |
|------|-------------|
| `resource_group_name` | Name of the created resource group. |
| `foundry_account_id` / `foundry_account_name` / `foundry_endpoint` | Details of the Foundry account. |
| `foundry_project_id` | Resource ID of the default Foundry project. |
| `search_service_id` / `search_service_name` | Details of the Azure AI Search service. |
| `cosmos_db_account_id` / `cosmos_db_endpoint` | Details of the Cosmos DB account (`null` when `enable_cosmos_db = false`). |
| `virtual_network_id` / `private_endpoint_subnet_id` / `agent_subnet_id` | Details of the created network (`null` when `enable_private_networking = false`). |

## Notes

- Foundry and Azure AI Search use Entra ID authentication; local API-key authentication is disabled.
- The Foundry account is granted access to Azure AI Search (`Search Service Contributor` and
  `Search Index Data Contributor`) and, when enabled, to Cosmos DB (`Cosmos DB Built-in Data Contributor`)
  via its system-assigned managed identity, and is wired up to both as Foundry connections.
- When `enable_private_networking = true`, public network access is automatically disabled on the
  Foundry account, Azure AI Search and Cosmos DB, and private endpoints + private DNS zones are created
  for each so they remain reachable from within the created VNet.
- A dedicated, delegated subnet (`agent_subnet_address_prefixes`) is created for future use with Foundry
  Agent Service network injection.
