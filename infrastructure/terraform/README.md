# E-commerce AKS Infrastructure - Terraform

This Terraform configuration deploys the complete Azure infrastructure for the e-commerce microservices project, including:

- **Azure Kubernetes Service (AKS)** - Managed Kubernetes cluster
- **Azure Container Registry (ACR)** - Private container registry
- **Virtual Network** - Network isolation with subnet
- **Log Analytics Workspace** - Centralized logging and monitoring
- **Azure Key Vault** - Secrets management (optional)
- **Public IP** - For ingress controller (optional)

## 📁 Project Structure

```
infrastructure/terraform/
├── main.tf              # Main infrastructure resources
├── variables.tf         # Variable definitions
├── outputs.tf           # Output values
├── terraform.tfvars     # Variable values (customize this)
├── README.md           # This file
├── deploy.sh           # Deployment helper script ⭐ NEW
└── environments/       # Environment-specific configs
    ├── dev.tfvars           # Development configuration
    ├── staging.tfvars       # Staging configuration
    ├── prod.tfvars          # Production configuration
    └── comparison.md        # Environment comparison guide
```

## 🚀 Quick Start

### Prerequisites

1. **Install Terraform** (v1.5.0 or higher)

   ```bash
   # macOS
   brew install terraform

   # Windows (Chocolatey)
   choco install terraform

   # Linux
   wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
   unzip terraform_1.5.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **Install Azure CLI**

   ```bash
   # macOS
   brew install azure-cli

   # Windows
   winget install Microsoft.AzureCLI

   # Linux
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```

3. **Login to Azure**

   ```bash
   az login

   # Set your subscription
   az account set --subscription "YOUR_SUBSCRIPTION_ID"

   # Verify
   az account show
   ```

### Quick Deploy Using Helper Script (Recommended) ⭐

The easiest way to deploy is using the included `deploy.sh` script:

```bash
# Make script executable
chmod +x deploy.sh

# Deploy to development
./deploy.sh apply dev

# Deploy to staging
./deploy.sh apply staging

# Deploy to production
./deploy.sh apply prod

# Connect to cluster
./deploy.sh connect dev

# Show outputs
./deploy.sh output dev

# Destroy infrastructure
./deploy.sh destroy dev
```

### Manual Deployment (Alternative)

### Step 1: Initialize Terraform

```bash
# Navigate to terraform directory
cd infrastructure/terraform

# Initialize Terraform (downloads providers)
terraform init
```

### Step 2: Customize Variables

Edit `terraform.tfvars`:

```hcl
# For Dev Environment
environment  = "dev"
location     = "eastus"
project_name = "ecommerce-aks"

# For Prod Environment (use different file)
# environment  = "prod"
# acr_sku      = "Premium"
# system_node_count = 3
# user_node_count   = 3
```

### Step 3: Plan (Preview Changes)

```bash
# Preview what will be created
terraform plan

# Save plan to file
terraform plan -out=tfplan
```

### Step 4: Apply (Create Resources)

```bash
# Apply the configuration
terraform apply

# Or use saved plan
terraform apply tfplan
```

**Estimated creation time:** 10-15 minutes

### Step 5: Get Outputs

```bash
# View all outputs
terraform output

# Get specific output
terraform output aks_cluster_name
terraform output acr_login_server

# Get sensitive outputs
terraform output -raw aks_kube_config > kubeconfig.yaml
```

### Step 6: Connect to AKS

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)

# Verify connection
kubectl get nodes

# Login to ACR
az acr login --name $(terraform output -raw acr_name)
```

## 📝 Multiple Environments

### Option 1: Separate `.tfvars` Files

Create environment-specific variable files:

```bash
# Create directories
mkdir -p environments

# Dev environment
cat > environments/dev.tfvars <<EOF
environment  = "dev"
acr_sku      = "Basic"
system_node_count = 2
user_node_count   = 2
EOF

# Staging environment
cat > environments/staging.tfvars <<EOF
environment  = "staging"
acr_sku      = "Standard"
system_node_count = 2
user_node_count   = 3
EOF

# Production environment
cat > environments/prod.tfvars <<EOF
environment  = "prod"
acr_sku      = "Premium"
system_node_count = 3
user_node_count   = 5
create_key_vault = true
acr_georeplications = [
  {
    location                = "westus2"
    zone_redundancy_enabled = true
  }
]
EOF
```

Deploy to specific environment:

```bash
# Deploy to dev
terraform apply -var-file="environments/dev.tfvars"

# Deploy to staging
terraform apply -var-file="environments/staging.tfvars"

# Deploy to prod
terraform apply -var-file="environments/prod.tfvars"
```

### Option 2: Terraform Workspaces

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch workspace
terraform workspace select dev

# Apply
terraform apply
```

## 🔒 Remote State Management (Recommended)

Store Terraform state in Azure Storage:

### 1. Create Storage Account

```bash
# Variables
RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="tfstate$(date +%s)"
CONTAINER_NAME="tfstate"
LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --encryption-services blob

# Get account key
ACCOUNT_KEY=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP \
  --account-name $STORAGE_ACCOUNT \
  --query '[0].value' -o tsv)

# Create container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT \
  --account-key $ACCOUNT_KEY
```

### 2. Configure Backend in `main.tf`

Uncomment the backend block in `main.tf`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstate1234567890"  # Your storage account name
    container_name       = "tfstate"
    key                  = "ecommerce-dev.tfstate"  # Change per environment
  }
}
```

### 3. Initialize with Backend

```bash
terraform init -backend-config="key=ecommerce-dev.tfstate"
```

## 🛠️ Common Commands

```bash
# Format code
terraform fmt

# Validate configuration
terraform validate

# Show current state
terraform show

# List resources
terraform state list

# Import existing resource
terraform import azurerm_resource_group.main /subscriptions/XXX/resourceGroups/rg-name

# Destroy specific resource
terraform destroy -target=azurerm_public_ip.ingress

# Destroy everything
terraform destroy

# Refresh state
terraform refresh

# Taint resource (force recreation)
terraform taint azurerm_kubernetes_cluster.aks
```

## 📊 Resource Naming Convention

Resources follow this naming pattern:

| Resource Type  | Pattern                | Example                  |
| -------------- | ---------------------- | ------------------------ |
| Resource Group | `rg-{project}-{env}`   | `rg-ecommerce-aks-dev`   |
| AKS Cluster    | `aks-{project}-{env}`  | `aks-ecommerce-aks-dev`  |
| ACR            | `acr{project}{env}`    | `acrecommerceaksdev`     |
| VNet           | `vnet-{project}-{env}` | `vnet-ecommerce-aks-dev` |
| Subnet         | `snet-aks-{env}`       | `snet-aks-dev`           |
| Log Analytics  | `log-{project}-{env}`  | `log-ecommerce-aks-dev`  |
| Key Vault      | `kv{project}{env}`     | `kvecommerceaksdev`      |

## 💰 Cost Optimization

### Dev Environment (Low Cost)

```hcl
environment        = "dev"
acr_sku           = "Basic"              # $5/month
system_node_size  = "Standard_B2s"       # $30/month per node
user_node_size    = "Standard_B2s"       # $30/month per node
system_node_count = 1
user_node_count   = 1
availability_zones = ["1"]                # Single zone
```

**Estimated monthly cost:** ~$100-150

### Production Environment (High Availability)

```hcl
environment        = "prod"
acr_sku           = "Premium"            # $500/month (geo-replication)
system_node_size  = "Standard_D2s_v3"    # $70/month per node
user_node_size    = "Standard_D4s_v3"    # $140/month per node
system_node_count = 3
user_node_count   = 3
availability_zones = ["1", "2", "3"]     # Multi-zone
```

**Estimated monthly cost:** ~$1,500-2,000

## 🔍 Troubleshooting

### Error: "subscription not registered"

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
```

### Error: "ACR name not available"

ACR names must be globally unique. Change `project_name` in `terraform.tfvars`.

### Error: "insufficient quota"

Request quota increase:

```bash
az vm list-usage --location eastus --output table
```

### Can't connect to AKS

```bash
# Get credentials again
az aks get-credentials --resource-group RESOURCE_GROUP --name CLUSTER_NAME --overwrite-existing

# Check cluster status
az aks show --resource-group RESOURCE_GROUP --name CLUSTER_NAME --query "provisioningState"
```

## 🔄 Updating Infrastructure

```bash
# Modify terraform.tfvars or .tf files

# Plan changes
terraform plan

# Apply changes
terraform apply
```

### Safe Updates:

- ✅ Changing node counts (autoscaling)
- ✅ Adding tags
- ✅ Updating Log Analytics retention
- ✅ Adding Key Vault access policies

### Disruptive Updates (require recreation):

- ⚠️ Changing AKS cluster name
- ⚠️ Changing VNet CIDR
- ⚠️ Changing ACR name

## 🧹 Cleanup

```bash
# Destroy all resources
terraform destroy

# Or destroy specific environment
terraform destroy -var-file="environments/dev.tfvars"

# Confirm with 'yes'
```

## 📚 Additional Resources

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [AKS Best Practices](https://docs.microsoft.com/en-us/azure/aks/best-practices)
- [Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/)

## 🤝 Comparison: Bicep vs Terraform

| Feature          | Bicep             | Terraform        |
| ---------------- | ----------------- | ---------------- |
| Cloud Support    | Azure only        | Multi-cloud      |
| State Management | Azure manages     | Manual or remote |
| Learning Curve   | Easier for Azure  | Steeper          |
| Community        | Growing           | Mature           |
| Modules          | Azure Quick Start | Rich ecosystem   |

**When to use Terraform:**

- Multi-cloud deployments
- Large community/modules needed
- Complex state management
- Industry standard

**When to use Bicep:**

- Azure-only projects
- Simpler syntax preferred
- Native Azure integration
- Newer teams to IaC
