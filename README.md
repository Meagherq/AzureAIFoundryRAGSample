# Azure AI Foundry RAG Sample with Azure AI Search

> **Disclaimer:** This repository is provided purely as a demonstration of these workflows. You are free to use, modify, and adapt the code as you see fit; however, it is offered as-is with no warranty or support of any kind. Use it at your own risk. This is not production-ready code — it should be reviewed, understood, and rewritten to suit your own environment before any real-world use.

This repository demonstrates how to build a complete Retrieval-Augmented Generation (RAG) solution using Azure AI Foundry. The solution connects an AI Agent to document data stored in Azure Blob Storage through Azure AI Search.

## Architecture Overview

The solution deploys the following resources:

*   **Azure OpenAI Service:** Hosts the GPT model and AI Agent.
*   **Azure AI Foundry Project:** Manages the AI Agent configuration.
*   **Azure AI Search:** Indexes documents from blob storage and provides semantic search capabilities for RAG.
*   **Azure Storage Account:** Stores source documents (invoice .txt files) in a blob container named `test`.
*   **Existing Virtual Network (VNet):** Provides the secure network boundary used by the solution.
*   **Private Endpoints:** Connect the VNet securely to Cognitive Services, Azure AI Search, Storage, and Key Vault.
*   **Existing Private DNS Zones:** Support private name resolution; DNS zone groups must be configured manually.
*   **Supporting Services:** Key Vault, Application Insights, and Log Analytics for observability.

## How RAG Works in This Solution

1.  **Document Storage:** Invoice documents (`.txt` files) are uploaded to the Storage Account's `test` container by the user.
2.  **Indexing Pipeline:** An Azure AI Search indexer automatically:
    *   Connects to the blob container via a datasource (configured with managed identity)
    *   Extracts content and metadata from documents using a skillset
    *   Applies AI skills including key phrase extraction
    *   Populates the search index (`ragdocs`) with indexed content
3.  **Agent Query:** When a user asks a question through the AI Agent:
    *   The agent uses Azure AI Search to find relevant document chunks from the indexed invoices
    *   Retrieved context is combined with the user's question
    *   The GPT model generates a grounded response based on the indexed documents
4.  **Secure Access:** Private endpoints and Microsoft Entra ID authentication protect access to the Azure services.

## Security Posture

This architecture prioritizes security by minimizing public exposure and using identity-based authentication.

### Network Security
*   **Private Backend:** When `enable_private_networking` is enabled, account-wide public network access is disabled. The separately configured `enable_m365_public_endpoint` exception allows authenticated Microsoft channel traffic only to the Activity Protocol route.
*   **VNet Integration:** Cognitive Services, Azure AI Search, Storage, and Key Vault each own a Private Endpoint in the externally managed private-endpoint subnet.
*   **DNS Management:** Terraform looks up existing Private DNS Zones, but the Private DNS Zone Group blocks are commented out because this repository requires manual DNS configuration.

### Authentication & Authorization
*   **Identity-Based Access:** The solution is configured to use Azure Active Directory (Entra ID) tokens.
*   **Identity-Based Access:** Clients authenticate directly with Microsoft Entra ID.
*   **No Static Keys:** The solution uses managed identities and role assignments where supported.

### API Policy
*   **CORS:** A Cross-Origin Resource Sharing (CORS) policy is applied to allow safe cross-origin requests from web clients.
*   **Token Limiting:** An `llm-token-limit` policy is configured to manage consumption, limiting usage to 5,000 tokens per minute and 50,000 tokens per hour per IP address.

## Data Path

1.  **Client Request:** A user or application sends an authenticated HTTPS request to the Azure AI Foundry project endpoint.
    *   URL: Use the Azure AI Foundry project endpoint available to your network.
    *   Header: `Authorization: Bearer <valid-azure-ad-token>`
2.  **Service Entry:** The request reaches the Azure AI Foundry project endpoint.
3.  **DNS Resolution:** The client environment queries the existing Private DNS Zones linked to the VNet.
4.  **Private Routing:** The DNS zone returns the **Private IP** address of the backend service.
5.  **Backend Access:** Traffic reaches the Azure AI Foundry Project through its Private Endpoint.
6.  **Response:** The model processes the request and returns the response via the same secure path.

## Deployment

### Prerequisites
*   Azure CLI (`az`)
*   Terraform (>= 1.3; >= 1.7 to run mocked tests)
*   PowerShell
*   An active Azure Subscription with sufficient permissions to create resources and assign RBAC roles

### Optional Terraform Inputs

Set `enable_rbac = false` when role assignments are managed manually. The role-assignment resources remain in `terraform/project/main.tf` and are enabled by setting `enable_rbac = true`.

Provide `existing_network_resource_group_name`, `existing_vnet_name`, and `existing_private_endpoint_subnet_name` for the externally managed network. Also provide `existing_agent_subnet_name` for a dedicated `/27` or larger subnet delegated to `Microsoft.App/environments`; Foundry Agent Service uses this subnet for VNet-injected outbound traffic to private dependencies such as Azure AI Search. Set `private_dns_subscription_id` and `existing_private_dns_zone_resource_group_name` for the Private DNS Zones in the separate DNS subscription and, if the standard names are not used, override the zone name inputs. Terraform uses an aliased AzureRM provider to read the zones from that subscription. Configure the DNS zone groups and VNet links manually.

The agent definition defaults to `terraform/modules/azurerm/ai_agent/agent_definition.yaml.tftpl`. Set `agent_definition_template_file` to use a custom YAML template; Terraform interpolates the agent name, model deployment, search connection ID, and index name while leaving the instructions in YAML.

### SharePoint grounding connections

Set `sharepoint_connections` to create zero, one, or multiple Foundry project connections. Each map key is a connection name; each `site_url` scopes retrieval to a SharePoint site or folder. Terraform attaches all connections to **one** `sharepoint_grounding_preview` tool alongside the existing Azure AI Search tool:

```hcl
sharepoint_connections = {
  sharepoint-policies = {
    site_url = "https://contoso.sharepoint.com/sites/Policies"
  }
  sharepoint-finance = {
    site_url         = "https://contoso.sharepoint.com/sites/Finance/Shared%20Documents/Invoices"
    is_shared_to_all = false
  }
}
```

An empty map (the default) preserves the search-only agent. Connection names must be 3-33 characters, start with an alphanumeric character, and contain only alphanumerics, underscores, or hyphens. Don't reuse the search connection name (`ragdocs`). Use site/folder URLs, not browser URLs with query strings or fragments. Connections default to `is_shared_to_all = false`; sharing a connection does not grant users access to SharePoint documents.

The module appends the SharePoint tool after rendering either the built-in or a custom YAML template. When using `sharepoint_connections`, don't also define a SharePoint tool in your custom template; Foundry supports only one SharePoint tool per agent. Customize your agent instructions for the content and questions you expect it to answer. The `sharepoint_connection_ids` output exposes the created connection IDs.

**Authentication and service limitations:** SharePoint grounding is a preview and requires delegated user identity (identity passthrough/on-behalf-of), not application-only or managed-identity authentication. The Foundry project and SharePoint site must be in the same Entra tenant. Users need SharePoint read access, the appropriate Foundry role, and Microsoft 365 Copilot licensing or eligible pay-as-you-go retrieval. The `CustomKeys` connection stores the site URL, not a SharePoint credential; it does not bypass user permissions. Validate retrieval with both an authorized user and a user denied access to the same document. See the [SharePoint tool documentation](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/tools/sharepoint).

**Channel compatibility:** The SharePoint tool documentation currently warns that the tool doesn't work when the agent is published to Microsoft Teams. Enabling the M365 endpoint is a separate capability and does not resolve delegated-authentication or channel limitations. Test SharePoint retrieval through your intended Microsoft 365 Copilot channel before rollout; direct Foundry retrieval alone is not sufficient verification.

### Microsoft 365 Copilot / Activity Protocol access

The dev environment defaults to the following settings (the reusable project/agent modules default public M365 access to `false`):

```hcl
enable_m365_public_endpoint = true
m365_authorization_scheme  = "BotServiceRbac"
```

After creating the agent version, Terraform reads its current endpoint configuration and patches `agent_endpoint.protocol_configuration.activity.enable_m365_public_endpoint`. It preserves existing protocols and direct-client authorization, retains/adds Responses access, and selects the configured Bot Service authorization scheme. Setting the flag back to `false` explicitly disables the public Activity route exception on the next apply; it does not remove other protocols or authorization.

This setting **does not enable account-wide public network access** and is independent of `enable_private_networking`. For private Foundry accounts, Microsoft manages source-IP filtering so Azure Bot Service/M365 can reach only the public Activity Protocol route; management and other APIs remain private. Authentication and authorization are still required. Run Terraform from a client that can reach the project endpoint.

- Use `BotServiceRbac` for `Shared`/`Personal` publishing scope (Foundry permissions required).
- Use `BotServiceTenant` for `Tenant` publishing scope (tenant-wide access; admin approval required).
- The `activity_protocol_endpoint` output supplies the Azure Bot Service messaging URL.
- This repository configures endpoint access, **not** Azure Bot Service creation, Teams channel registration, catalog publishing, or admin consent. Complete those steps using [Publish agents to Microsoft 365 and Teams by using the REST API](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/publish-copilot-virtual-network). Match the publishing scope to your authorization scheme; publishing can replace the Bot Service scheme.
- Before rollout, verify an authenticated Copilot conversation, expected SharePoint citations/permission trimming, and rejection of unauthorized requests.

### Configuration tests

With PowerShell 7, Terraform >= 1.7 (for test mocks), and initialized Terraform providers, run the focused offline tests:

```powershell
terraform -chdir=terraform/modules/azurerm/ai_agent init -backend=false
terraform -chdir=terraform/modules/azurerm/ai_agent test
pwsh -NoProfile -File terraform/modules/azurerm/ai_agent/tests/configure_agent_endpoint.tests.ps1
```

The Terraform tests initialize only a mocked search connection in memory, then use plan-only runs for the agent and endpoint; no provisioners execute. The PowerShell tests mock Azure CLI calls. Neither deploys resources or invokes a live agent.

The dev example also includes a commented GPT-5.6 Luna profile (`gpt-5.6-luna`, version `2026-07-09`). Check model availability and quota for the target region before enabling it. GPT-5.6 tool calling is documented through the Responses API, so confirm compatibility with this sample's Assistants-style agent creation flow before switching.

### Step 1: Deploy Infrastructure

#### Option A: Local Deployment (Manual)

1.  Navigate to the `terraform/environments/dev` directory:
    ```bash
    cd terraform/environments/dev
    ```

2.  Copy the example variables file:
    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```

3.  Update `terraform.tfvars` with your specific values (for example, `subscription_id`, `workload`, and the existing network resource names).

4.  Initialize Terraform:
    ```bash
    terraform init
    ```

    State is stored locally by default. To use remote state in Azure Storage instead, create `backend.tf` in this folder before running init:
    ```hcl
    terraform {
      backend "azurerm" {
        resource_group_name  = "rg-tfstate"
        storage_account_name = "sttfstatedev"
        container_name       = "tfstate"
        key                  = "aifoundry-rag.tfstate"
        use_azuread_auth     = true
      }
    }
    ```

5.  **First Apply** - Deploy the infrastructure:
    ```bash
    terraform apply
    ```
    
    **Note:** With `enable_rbac = true`, the first apply may encounter role-assignment propagation delays while managed identities are created.

6.  **Second Apply** - Complete role assignments:
    ```bash
    terraform apply
    ```
    
    When `enable_rbac = true`, run apply again after identity propagation to complete role assignments. When `enable_rbac = false`, provision the required roles manually before creating or using the agent.

7.  **Capture Outputs:** Note the following Terraform outputs for later steps:
    *   `resource_group_name`
    *   `search_service_name`
    *   `cognitive_service_endpoint`
    *   `search_service_endpoint`

### Option B: Deploy via GitHub Actions (CI/CD)

This repository includes GitHub Actions workflows for automated deployment, destruction, and backend bootstrapping.

#### 1. Create a Service Principal with OIDC Federation

Create an Entra ID app registration and configure federated credentials for GitHub Actions (no client secret required):

```powershell
# Set your values
$GITHUB_ORG = "<your-github-org-or-username>"
$GITHUB_REPO = "<your-repo-name>"
$SUBSCRIPTION_ID = "<your-azure-subscription-id>"

# Create the app registration
$APP_ID = az ad app create --display-name "github-actions-aifoundry" --query appId -o tsv

# Create the service principal
$SP_OBJECT_ID = az ad sp create --id $APP_ID --query id -o tsv

# Assign Owner on the subscription (needed for resource creation + RBAC assignments)
az role assignment create `
  --role "Owner" `
  --assignee-object-id $SP_OBJECT_ID `
  --assignee-principal-type ServicePrincipal `
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Add federated credential for the "dev" environment
$devParams = (@{
  name      = "github-env-dev"
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:dev"
  audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Compress) -replace '"', '\"'
az ad app federated-credential create --id $APP_ID --parameters $devParams

# Add federated credential for the main branch (used by the plan job)
$mainParams = (@{
  name      = "github-ref-main"
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main"
  audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Compress) -replace '"', '\"'
az ad app federated-credential create --id $APP_ID --parameters $mainParams

# Print the values you need for GitHub secrets
$TENANT_ID = az account show --query tenantId -o tsv
Write-Host "AZURE_CLIENT_ID=$APP_ID"
Write-Host "AZURE_TENANT_ID=$TENANT_ID"
Write-Host "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
```

#### 2. Configure GitHub Secrets & Variables

In your repository go to **Settings > Secrets and variables > Actions**.

**Secrets** (sensitive):

| Secret | Description |
|---|---|
| `AZURE_CLIENT_ID` | App registration client/application ID (from step above) |
| `AZURE_TENANT_ID` | Azure AD / Entra ID tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID |

**Variables** (non-sensitive — set after bootstrapping the backend in step 3):

| Variable | Description | Example |
|---|---|---|
| `TF_BACKEND_RESOURCE_GROUP` | Resource group for Terraform state storage | `rg-tfstate` |
| `TF_BACKEND_STORAGE_ACCOUNT` | Storage account name for state | `sttfstatedev` |
| `TF_BACKEND_CONTAINER` | Blob container name | `tfstate` |
| `TF_BACKEND_KEY` | State file blob name | `aifoundry-rag.tfstate` |

Also create a **`dev` environment** under **Settings > Environments** (optional: add required reviewers as an approval gate).

#### 3. Bootstrap the Terraform State Backend

Run the **"Bootstrap Terraform Backend"** workflow from **Actions > Bootstrap Terraform Backend > Run workflow**. Provide the resource group name, storage account name, container name, and Azure region. The workflow will:

- Create the resource group and storage account (TLS 1.2, no public blob access)
- Create the blob container
- Grant the service principal `Storage Blob Data Contributor` on the storage account

After it completes, set the four `TF_BACKEND_*` variables listed above using the values from the workflow summary.

#### 4. Deploy

Push to `main` (changes under `terraform/`) or manually trigger the **"Deploy Infrastructure"** workflow. It runs `terraform plan`, then `terraform apply` twice (to handle RBAC propagation) with an environment approval gate.

#### 5. Destroy

Manually trigger the **"Destroy Infrastructure"** workflow from **Actions > Destroy Infrastructure > Run workflow**. You must type `destroy` in the confirmation input to proceed.

---

### Step 2: Grant Your User Storage Access

Before uploading documents, grant your Entra ID account `Storage Blob Data Contributor` access on the storage account

**Wait 2-5 minutes** for the role assignment to propagate before proceeding to the next step.

### Step 3: Upload Invoice Documents

Upload your invoice `.txt` files to the `test` container in the storage account. This solution is designed to work with generic invoice data in plain text format.

**Example Invoice Format (.txt):**
```
Invoice Number: INV-2024-001
Customer ID: CUST-12345
Date: 2024-01-15
Amount: $1,250.00
Description: Professional Services
...
```

### Step 4: Run the Search Indexer

After uploading documents, trigger the indexer to process and index the documents:

**Verify Indexing:**
*   Check the indexer status in the Azure Portal: Navigate to your Search Service → **Indexers** → `doc-indexer`
*   Wait for the indexer to complete (status should show "Success")
*   Verify documents are indexed: Check the document count in the search index (`ragdocs`)

### Step 5: Test the Agent

#### Option A: Azure AI Foundry Studio (Recommended)

1.  Navigate to [Azure AI Foundry Studio](https://ai.azure.com)
2.  Sign in with your Azure account
3.  Open your AI project (format: `<workload>-<env>-<suffix>`)
4.  Go to **Agents** in the left navigation
5.  Select your agent: `agent-<workload>-<env>-<suffix>`
6.  Use the **Playground** to test queries:
    *   "What invoices do we have?"
    *   "Show me details for invoice INV-2024-001"
    *   "What's the total amount for customer CUST-12345?"
    *   "List all invoices from January 2024"

The agent should retrieve relevant information from your indexed invoice documents.

## Usage

### Web Application
1.  Open `app/index.html` in your browser.
2.  Fill in the configuration:
    *   **Agent API Base URL:** Enter the Azure AI Foundry project endpoint that is reachable from your network.
    *   **Agent Name/ID:** Enter the Agent ID from the Foundry Studio (e.g., `asst_...`).
    *   **API Version:** Default is `v1` (for Foundry Agents) or `2024-05-01-preview` (for Azure OpenAI).
    *   **Access Token:** Generate a token using:
        ```bash
        az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv
        ```
3.  Start chatting!

## Search Index Schema

The Azure AI Search index (`ragdocs`) includes the following fields designed for invoice data:

*   `id` - Unique identifier (key)
*   `parent_id` - Parent document reference
*   `content` - Full text content
*   `blob_url` - Source blob URL
*   `metadata_storage_path` - Storage path
*   `metadata_storage_name` - File name
*   `metadata_storage_last_modified` - Last modified timestamp
*   `metadata_storage_size` - File size
*   `invoiceNo` - Invoice number (searchable, filterable, facetable)
*   `customerId` - Customer identifier (searchable, filterable, facetable)

The indexer uses a skillset with key phrase extraction to enhance search quality.

## Troubleshooting

### Indexer Fails to Run
*   Verify the Search service has `Storage Blob Data Reader` role on the Storage Account
*   Check that documents exist in the `test` container
*   Review indexer execution history in Azure Portal

### Agent Returns Generic Responses
*   Verify documents are indexed: Check document count in Search service
*   Ensure the agent is connected to the correct search index (`ragdocs`)
*   Test search directly in the Azure Portal Search Explorer

### RBAC Permission Errors
*   Wait 2-5 minutes after role assignments for propagation
*   Run `terraform apply` a second time to resolve timing issues
*   Verify you're logged in with `az account show`

### Token Expired
*   Access tokens expire after 1 hour
*   Regenerate with: `az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv`
