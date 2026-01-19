# Bicep Deployment Troubleshooting Guide

Common issues and solutions when deploying AKS infrastructure with Bicep.

---

## 🚨 Error: Authorization Failed for Role Assignment

### Error Message

```
Authorization failed for template resource 'xxx' of type 'Microsoft.Authorization/roleAssignments'.
The client 'xxx' does not have permission to perform action 'Microsoft.Authorization/roleAssignments/write'
```

### Cause

Your Azure service principal or user account doesn't have permission to assign roles (requires `User Access Administrator` or `Owner` role).

### Solution Options

#### **Option 1: Use the No-RBAC Template (Recommended for Limited Permissions)**

```bash
# Use the alternative template without automatic role assignment
az deployment group create \
  --resource-group rg-ecommerce-aks-dev \
  --template-file main-no-rbac.bicep \
  --parameters @parameters.dev.json
```

Then manually assign the ACR role:

**Linux/Mac:**

```bash
chmod +x fix-acr-permissions.sh
./fix-acr-permissions.sh dev
```

**Windows:**

```powershell
.\fix-acr-permissions.ps1 -Environment dev
```

#### **Option 2: Grant Additional Permissions to Service Principal**

```bash
# Get your service principal ID
SP_ID=$(az ad sp list --display-name "azure-ecommerce-sp" --query "[0].id" -o tsv)

# Grant User Access Administrator role at resource group level
az role assignment create \
  --assignee $SP_ID \
  --role "User Access Administrator" \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-ecommerce-aks-dev
```

#### **Option 3: Comment Out Role Assignment in Bicep**

Edit `main.bicep` and comment out the role assignment section:

```bicep
// ============================================
// 6. RBAC Assignment for ACR Pull
// ============================================
/*
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, aks.id, 'acrpull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}
*/
```

Then deploy and manually assign permissions after.

---

## 🔴 Error: MissingSubscriptionRegistration

### Error Message

```
The subscription is not registered to use namespace 'Microsoft.OperationsManagement'
The subscription is not registered to use namespace 'Microsoft.OperationalInsights'
```

### Cause

Required Azure resource providers are not registered in your subscription. This is common with new subscriptions or subscriptions that haven't used these services before.

### Solution

**Quick Fix - Register Individual Provider:**

```bash
# Register the missing provider
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.OperationalInsights

# Wait for registration (takes 1-2 minutes)
az provider show --namespace Microsoft.OperationsManagement --query "registrationState"
az provider show --namespace Microsoft.OperationalInsights --query "registrationState"
```

**Comprehensive Fix - Register All Required Providers:**

Use the provided registration script:

**Linux/Mac:**

```bash
chmod +x register-providers.sh
./register-providers.sh
```

**Windows:**

```powershell
.\register-providers.ps1
```

**Manual Registration:**

```bash
# List of all required providers
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Storage

# Check registration status (wait until all show "Registered")
az provider list --query "[?namespace=='Microsoft.OperationsManagement' || namespace=='Microsoft.OperationalInsights'].{Namespace:namespace, State:registrationState}" -o table
```

**Then retry deployment:**

```bash
az deployment group create \
  --resource-group rg-ecommerce-aks-dev \
  --template-file main-no-rbac.bicep \
  --parameters @parameters.dev.json
```

---

## ⚠️ Warning: adminusername-should-not-be-literal

### Warning Message

```
Property 'adminUserName' should not use a literal value. Use a param instead.
```

### Cause

Hard-coded admin username in Bicep template.

### Solution

✅ **Already Fixed!** The updated template now uses a parameter:

```bicep
@description('Admin username for AKS nodes')
param adminUsername string = 'azureuser'

linuxProfile: {
  adminUsername: adminUsername
  ...
}
```

---

## 🌐 Error: Invalid Subnet Resource ID

### Error Message

```
InvalidSubnetSourceID: '[reference(resourceId('Microsoft.Network/virtualNetworks', variables('vnetName')), '2023-05-01').subnets[0].id]' is not a valid vnet subnet ResourceID
```

### Cause

The Bicep template is using an incorrect method to reference the subnet ID. Using `.properties.subnets[0].id` or `reference()` function creates a circular dependency or invalid reference.

### Solution

✅ **Already Fixed!** The updated templates now use the correct `resourceId()` function:

```bicep
// Before (caused error)
vnetSubnetID: vnet.properties.subnets[0].id

// After (fixed)
vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'aks-subnet')
```

**Additional fixes:**

- Added explicit `dependsOn: [vnet]` to AKS cluster resource
- Fixed output expressions to use `reference()` function correctly

**If you're using an older template:**
Update to the latest `main.bicep` or `main-no-rbac.bicep` from the repository.

---

## ⚠️ Warning: BCP318 - Value May Be Null

### Warning Message

```
The value of type "Microsoft.Network/publicIPAddresses | null" may be null
```

### Cause

Conditional resource (publicIP) may not exist in dev environment, but outputs try to access its properties.

### Solution

✅ **Already Fixed!** The outputs now handle null values:

```bicep
output publicIPAddress string = environment != 'dev' ? publicIP.properties.ipAddress : 'N/A'
output publicIPFQDN string = environment != 'dev' ? publicIP.properties.dnsSettings.fqdn : 'N/A'
```

---

## 🔌 Error: kubectl Connection Refused to localhost:8080

### Error Message

```
The connection to the server localhost:8080 was refused - did you specify the right host or port?
couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
```

### Cause

kubectl is not configured to connect to your AKS cluster. The kubeconfig file is either missing, corrupted, or pointing to the wrong cluster.

### Solution

**1. Get AKS credentials (overwrites current config):**

```bash
az aks get-credentials \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev \
  --overwrite-existing
```

**2. For admin access (recommended for troubleshooting):**

```bash
az aks get-credentials \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev \
  --overwrite-existing \
  --admin
```

**3. Verify the connection:**

```bash
# Check current context
kubectl config current-context

# View config
kubectl config view

# Test connection
kubectl cluster-info
kubectl get nodes
```

**4. If still failing, check kubeconfig location:**

```bash
# Linux/Mac
echo $KUBECONFIG
ls -la ~/.kube/config

# Windows
echo $env:KUBECONFIG
dir $env:USERPROFILE\.kube\config
```

**5. Set KUBECONFIG explicitly (if needed):**

```bash
# Linux/Mac
export KUBECONFIG=~/.kube/config

# Windows
$env:KUBECONFIG="$env:USERPROFILE\.kube\config"
```

**6. For Azure DevOps Pipeline:**
The issue occurs because the pipeline needs to explicitly get credentials in each task. Update your pipeline:

```yaml
- task: AzureCLI@2
  displayName: "Any kubectl command"
  inputs:
    azureSubscription: $(azureServiceConnection)
    scriptType: "bash"
    scriptLocation: "inlineScript"
    inlineScript: |
      # Always get credentials first
      az aks get-credentials \
        --resource-group $(resourceGroup) \
        --name $(aksClusterName) \
        --overwrite-existing \
        --admin

      # Then run kubectl commands
      kubectl get nodes
```

---

## 🐛 Error: Deployment Validation Failed

### Error Message

```
Deployment validation failed
```

### Troubleshooting Steps

1. **Check template syntax:**

   ```bash
   az bicep build --file main.bicep
   ```

2. **Validate deployment:**

   ```bash
   az deployment group validate \
     --resource-group rg-ecommerce-aks-dev \
     --template-file main.bicep \
     --parameters @parameters.dev.json
   ```

3. **Check parameter file:**
   - Verify SSH public key is valid
   - Ensure all required parameters are provided
   - Check JSON syntax

---

## 🔑 Error: SSH Key Invalid

### Error Message

```
The SSH public key is invalid
```

### Solution

Generate a proper SSH key:

```bash
# Generate new key
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa_aks -N ""

# Get the public key (without newlines)
SSH_KEY=$(cat ~/.ssh/id_rsa_aks.pub | tr -d '\n')

# Update parameters file
jq --arg ssh_key "$SSH_KEY" \
   '.parameters.sshPublicKey.value = $ssh_key' \
   parameters.dev.json > parameters.tmp.json
```

---

## 💾 Error: Insufficient Quota

### Error Message

```
Operation could not be completed as it results in exceeding approved quota
```

### Solution

Check and request quota increase:

```bash
# Check current quota
az vm list-usage --location eastus --output table

# Request quota increase
# Go to Azure Portal → Subscriptions → Usage + quotas
# Search for "Total Regional vCPUs" or "Standard BS Family vCPUs"
# Click "Request increase"
```

**Temporary Workaround:**

- Use smaller VM size (B1ms instead of B2ms)
- Deploy to different region
- Reduce node count to 1

---

## 🌐 Error: VNet Address Space Conflict

### Error Message

```
Address space overlaps with existing VNet
```

### Solution

Change VNet address space in `main.bicep`:

```bicep
addressSpace: {
  addressPrefixes: [
    '10.2.0.0/16'  // Changed from 10.0.0.0/16
  ]
}
subnets: [
  {
    name: 'aks-subnet'
    properties: {
      addressPrefix: '10.2.0.0/22'  // Changed from 10.0.0.0/22
    }
  }
]
```

---

## 🔒 Error: Service Principal Expired

### Error Message

```
The credentials in the service principal have expired
```

### Solution

Create new service principal:

```bash
# Delete old one
az ad sp delete --id <OLD_SP_ID>

# Create new one
az ad sp create-for-rbac \
  --name "azure-ecommerce-sp-new" \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth

# Update GitHub Secrets or Azure DevOps Service Connection
```

---

## 🛡️ Error: AzureDefender is disabled but Log Analytics workspace resource ID is not empty

### Error Message

```
AzureDefender is disabled but Log Analytics workspace resource ID is not empty
```

### Cause

The security profile configuration is trying to provide a Log Analytics workspace when Azure Defender is disabled for non-prod environments.

### Solution

✅ **Already Fixed!** The updated templates now conditionally configure the security profile:

```bicep
securityProfile: {
  defender: environment == 'prod' ? {
    logAnalyticsWorkspaceResourceId: logAnalytics.id
    securityMonitoring: {
      enabled: true
    }
  } : {
    securityMonitoring: {
      enabled: false
    }
  }
}
```

**If you're using the old template:**

1. Update to the latest `main.bicep` or `main-no-rbac.bicep`
2. Or remove the security profile section entirely for dev environments

---

## 📦 Error: ACR Name Already Taken

### Error Message

```
The container registry name is already in use
```

### Solution

ACR names must be globally unique. Change the name:

```json
// In parameters.dev.json
{
  "acrName": {
    "value": "acrecommerce<YOUR_INITIALS><RANDOM_NUMBER>"
  }
}
```

Or let Bicep generate unique name (default behavior):

```bicep
param acrName string = 'acrecommerce${uniqueString(resourceGroup().id)}'
```

---

## 🚫 Error: Resource Group Not Found

### Error Message

```
Resource group 'rg-ecommerce-aks-dev' could not be found
```

### Solution

Create the resource group first:

```bash
az group create \
  --name rg-ecommerce-aks-dev \
  --location eastus
```

---

## ⏱️ Error: Deployment Timeout

### Error Message

```
Deployment exceeded timeout of 90 minutes
```

### Solution

AKS cluster creation can take 10-15 minutes. If it times out:

1. **Check deployment status:**

   ```bash
   az deployment group show \
     --resource-group rg-ecommerce-aks-dev \
     --name <DEPLOYMENT_NAME>
   ```

2. **Check activity log:**

   ```bash
   az monitor activity-log list \
     --resource-group rg-ecommerce-aks-dev \
     --max-events 50
   ```

3. **Try deploying to different region** (some regions have capacity issues)

---

## 🔍 Verification After Deployment

### Check All Resources Created

```bash
# List all resources
az resource list \
  --resource-group rg-ecommerce-aks-dev \
  --output table

# Expected resources:
# - AKS cluster
# - ACR
# - Virtual Network
# - Log Analytics Workspace
# - Public IP (staging/prod only)
```

### Verify AKS Cluster

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev

# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system
```

### Verify ACR

```bash
# Test login
az acr login --name <ACR_NAME>

# List repositories (should be empty initially)
az acr repository list --name <ACR_NAME>
```

---

## 🆘 Still Having Issues?

### Collect Diagnostic Information

```bash
# Get deployment error details
az deployment group show \
  --resource-group rg-ecommerce-aks-dev \
  --name <DEPLOYMENT_NAME> \
  --query properties.error

# Get deployment operations
az deployment operation group list \
  --resource-group rg-ecommerce-aks-dev \
  --name <DEPLOYMENT_NAME>

# Export deployment template
az deployment group export \
  --resource-group rg-ecommerce-aks-dev \
  --name <DEPLOYMENT_NAME>
```

### Check Azure Service Health

```bash
# Check if there are any Azure outages
az rest --method get \
  --url "https://management.azure.com/subscriptions/<SUBSCRIPTION_ID>/providers/Microsoft.ResourceHealth/availabilityStatuses?api-version=2022-05-01"
```

### Clean Up and Retry

```bash
# Delete resource group
az group delete \
  --name rg-ecommerce-aks-dev \
  --yes \
  --no-wait

# Wait a few minutes, then retry deployment
```

---

## 📚 Useful Commands

### Deployment Management

```bash
# List all deployments in resource group
az deployment group list \
  --resource-group rg-ecommerce-aks-dev \
  --output table

# Delete a failed deployment
az deployment group delete \
  --resource-group rg-ecommerce-aks-dev \
  --name <DEPLOYMENT_NAME>

# Cancel a running deployment
az deployment group cancel \
  --resource-group rg-ecommerce-aks-dev \
  --name <DEPLOYMENT_NAME>
```

### Resource Management

```bash
# Check resource group tags
az group show \
  --name rg-ecommerce-aks-dev \
  --query tags

# Lock resource group (prevent deletion)
az lock create \
  --name prevent-delete \
  --resource-group rg-ecommerce-aks-dev \
  --lock-type CanNotDelete

# Remove lock
az lock delete \
  --name prevent-delete \
  --resource-group rg-ecommerce-aks-dev
```

---

## ✅ Success Checklist

After successful deployment, verify:

- [ ] Resource group created
- [ ] AKS cluster running
- [ ] ACR created
- [ ] VNet and subnets configured
- [ ] Log Analytics workspace active
- [ ] Can get AKS credentials
- [ ] Can login to ACR
- [ ] kubectl can connect to cluster
- [ ] Nodes are in Ready state
- [ ] ACR pull permissions assigned (or script available)

---

## 🆘 Get Help

- **Azure Documentation:** https://docs.microsoft.com/en-us/azure/aks/
- **Bicep Documentation:** https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/
- **Azure CLI Reference:** https://docs.microsoft.com/en-us/cli/azure/
- **Create Support Ticket:** Azure Portal → Help + support → New support request

---

Remember: Most deployment issues are related to permissions or quotas. Start with the solutions for those first!
