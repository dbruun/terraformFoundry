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

Install [Terraform](https://developer.hashicorp.com/terraform/install) and
[Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) and make sure both are on your `PATH`.
Terraform downloads the required providers during initialization; commit `.terraform.lock.hcl`
to retain the tested provider versions.

Your Azure identity needs permission to create resources and assign roles, for example
Contributor plus Role Based Access Control Administrator at the deployment scope.
Subscription-level access is needed to create the resource group. Resource providers
must also be registered: `Microsoft.CognitiveServices`, `Microsoft.Search`, and, for the
optional features, `Microsoft.DocumentDB`, `Microsoft.Network`, and `Microsoft.App`.
Ask your administrator to register providers if your identity cannot do so.

## Quick start (PowerShell)

Run these commands from the repository root. Run each step only after the previous
step succeeds. Deployment creates billable resources, including Standard Azure AI Search.

### 1. Sign in and select your Azure subscription

Find your subscription ID and tenant ID in Azure Portal under **Subscriptions > your
subscription > Overview**. Replace the placeholders with your own values:

```powershell
$env:ARM_SUBSCRIPTION_ID = "<your-subscription-id>"
$env:ARM_TENANT_ID = "<your-tenant-id>"

az login --tenant $env:ARM_TENANT_ID
az account set --subscription $env:ARM_SUBSCRIPTION_ID
az account show --query "{subscription:name,subscriptionId:id,tenantId:tenantId}" --output table
```

The `ARM_*` variables select Terraform's deployment target; they do not authenticate you.
The commands above use Azure CLI authentication and set environment variables for the
current PowerShell session only. Set them again in a new session, including before teardown.
For Bash, use `export ARM_SUBSCRIPTION_ID="..."` and `export ARM_TENANT_ID="..."` instead.
Leave `ARM_RESOURCE_PROVIDER_REGISTRATIONS` unset unless your administrator requires
manual provider registration; use `none` only when all required providers are registered.

### 2. Customize the deployment

Create your local settings file without overwriting one that already exists:

```powershell
if (-not (Test-Path terraform.tfvars)) {
    Copy-Item terraform.tfvars.example terraform.tfvars
}
```

Edit the local settings file using the complete, commented
[example](terraform.tfvars.example). It covers all supported inputs. For example,
change the corresponding entries to customize the resource names:

```hcl
name_prefix                  = "contoso"
resource_group_name          = "contoso-ai-dev-rg"
location                     = "eastus2"
foundry_account_name         = "contoso-ai-dev"
foundry_custom_subdomain_name = "contoso-ai-dev-unique123"
foundry_project_name         = "customer-assistant"
search_service_name          = "contoso-ai-search-unique123"
```

Choose your own globally unique Foundry subdomain and Search service name. Leave name
overrides as `null` to use derived names; `name_prefix` must contain 2-10 lowercase
letters or numbers. Do not add duplicate assignments to the settings file.

Terraform automatically loads `terraform.tfvars`; it does **not** automatically load
`terraform.tfvars.example`. Keep tenant/subscription selection in your shell and resource
settings in the variables file. Never put credentials in the example.

By default, this deploys a new resource group, Foundry account and project, Search service,
connection, and managed-identity role assignments. Cosmos DB and private networking are
disabled. It does not deploy Blob Storage, models, Search indexes, or a complete agent
application. Enabling Cosmos DB alone does not configure an Agent Service storage backend.

### 3. Validate, preview, and deploy

```powershell
terraform init
terraform validate
terraform plan -out=deploy.tfplan
```

Review the planned names, locations, costs, and any replacements or deletions before applying:

```powershell
terraform apply deploy.tfplan
terraform output
terraform plan -detailed-exitcode
```

Applying a saved plan executes it without another approval prompt. The final plan checks
for drift: exit code `0` means no changes, `2` means changes are proposed, and `1` means an
error. A successful plan does not guarantee regional capacity or Azure Policy approval;
these can still block creation during apply.

If Search reports `InsufficientResourcesAvailable`, choose an approved alternate region
with `search_location = "eastus"` (for example), then generate and review a new plan.
Do not delete state after a partial failure: Terraform uses it to resume or clean up.
Cross-region deployments may add latency and transfer costs. Changing names or regions
after creation can replace resources.

## Teardown

From the same working directory, with the same subscription/tenant environment variables
and Terraform state, run:

```powershell
terraform plan -destroy -out=destroy.tfplan
```

Review the deletion list, then execute it:

```powershell
terraform apply destroy.tfplan
terraform state list
```

An empty state list means Terraform no longer tracks any resources. Verify the resource
group is also gone in Azure Portal. This configuration allows deletion of a nonempty
resource group and purges the soft-deleted Foundry account on destroy. Do not add unrelated
resources to its resource group; they could be deleted along with it.

## State and source control

This configuration uses local Terraform state by default. Keep state until teardown is
complete; losing it does not delete the Azure resources or stop charges. For shared or
production use, configure a secured remote backend with access control and state locking.

State, backups, saved plans, local variable files, and `.env` files may contain sensitive
values and are excluded by [.gitignore](.gitignore). Do not force-add them. Publish the
Terraform source, sanitized example, documentation, and provider lock file, but not the
downloaded `.terraform/` provider directory. A state backup can retain sensitive data
even after resources have been destroyed.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `name_prefix` | Prefix used when naming all resources. | `"foundry"` |
| `location` | Azure region to deploy into. | `"eastus2"` |
| `resource_group_name` | Name of the resource group to create. | `<name_prefix>-rg` |
| `tags` | Tags applied to all taggable resources. | `{}` |
| `foundry_account_name` | Name of the Foundry (Cognitive Services `AIServices`) account. | `<name_prefix>-foundry` |
| `foundry_sku_name` | SKU for the Foundry account. | `"S0"` |
| `foundry_custom_subdomain_name` | Globally unique Foundry custom subdomain used for Entra ID authentication and private endpoints. | `<name_prefix>-foundry-<random>` |
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
- Private endpoints require client network connectivity and private DNS resolution. This configuration
  does not configure full Agent Service network injection or outbound connectivity.

## License

Licensed under the [MIT License](LICENSE).

Copyright (c) 2026 Microsoft Corporation.
