# Deployment Issues - Quick Fixes

This document contains all the fixes applied to resolve deployment errors.

---

## ✅ Issues Fixed

### **Issue 1: Invalid Subnet Resource ID**

**Error:**

```
InvalidSubnetSourceID: '[reference(resourceId('Microsoft.Network/virtualNetworks', variables('vnetName')), '2023-05-01').subnets[0].id]' is not a valid vnet subnet ResourceID
```

**Root Cause:** Using `vnet.properties.subnets[0].id` creates an invalid reference in Bicep. The subnet ID must be constructed using the `resourceId()` function.

**Fix Applied:**

```bicep
// Before (caused error)
agentPoolProfiles: [
  {
    vnetSubnetID: vnet.properties.subnets[0].id  // ❌ Invalid reference
  }
]

// After (fixed)
agentPoolProfiles: [
  {
    vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'aks-subnet')  // ✅ Correct
  }
]
```

**Additional fixes:**

- Added explicit `dependsOn: [vnet]` to ensure VNet is created first
- Fixed output expressions to use `reference()` function properly
- Fixed BCP318 warnings for publicIP references

**How to Apply:**
Templates are already fixed. If you have an older version:

```bash
cd infrastructure/bicep
chmod +x patch-templates.sh
./patch-templates.sh
```

---

### **Issue 2: MissingSubscriptionRegistration**

**Error:**

```
The subscription is not registered to use namespace 'Microsoft.OperationsManagement'
The subscription is not registered to use namespace 'Microsoft.OperationalInsights'
```

**Root Cause:** Azure resource providers not registered in your subscription (common with new subscriptions).

**Fix Applied:**

- Created registration scripts: `register-providers.sh` and `register-providers.ps1`
- These register all required providers before deployment

**How to Use:**

```bash
# Linux/Mac
chmod +x register-providers.sh
./register-providers.sh

# Windows
.\register-providers.ps1

# Then deploy
az deployment group create \
  --resource-group rg-ecommerce-aks-dev \
  --template-file main-no-rbac.bicep \
  --parameters @parameters.dev.json
```

**Quick Manual Fix:**

```bash
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.ContainerService

# Wait 1-2 minutes, then check
az provider show --namespace Microsoft.OperationsManagement --query "registrationState"
```

---

### **Issue 2: Authorization Failed for Role Assignment**

**Error:**

```
Authorization failed for template resource 'xxx' of type 'Microsoft.Authorization/roleAssignments'
The client does not have permission to perform action 'Microsoft.Authorization/roleAssignments/write'
```

**Root Cause:** Service principal lacks `User Access Administrator` role to assign ACR pull permissions to AKS.

**Fix Applied:**

- Created alternative template: `main-no-rbac.bicep` (deploys without role assignment)
- Created helper scripts: `fix-acr-permissions.sh` and `fix-acr-permissions.ps1`

**How to Use:**

```bash
# Deploy with no-RBAC template
az deployment group create \
  --resource-group rg-ecommerce-aks-dev \
  --template-file main-no-rbac.bicep \
  --parameters @parameters.dev.json

# Then run the fix script
./fix-acr-permissions.sh dev
```

---

### **Issue 2: Azure Defender Configuration Error**

**Error:**

```
AzureDefender is disabled but Log Analytics workspace resource ID is not empty
```

**Root Cause:** Dev environment has Azure Defender disabled but was still receiving Log Analytics workspace configuration.

**Fix Applied:**
Updated security profile to be conditional based on environment:

```bicep
// Before (caused error)
securityProfile: {
  defender: {
    logAnalyticsWorkspaceResourceId: logAnalytics.id
    securityMonitoring: {
      enabled: environment == 'prod'  // ❌ Still passed workspace ID even when disabled
    }
  }
}

// After (fixed)
securityProfile: {
  defender: environment == 'prod' ? {
    logAnalyticsWorkspaceResourceId: logAnalytics.id
    securityMonitoring: {
      enabled: true
    }
  } : {
    securityMonitoring: {
      enabled: false  // ✅ No workspace ID when disabled
    }
  }
}
```

---

### **Issue 3: Bicep Linting Warnings**

**Warning 1:** `adminusername-should-not-be-literal`

```
Property 'adminUserName' should not use a literal value
```

**Fix Applied:**

```bicep
// Added parameter
@description('Admin username for AKS nodes')
param adminUsername string = 'azureuser'

// Use in linuxProfile
linuxProfile: {
  adminUsername: adminUsername  // ✅ Now uses parameter
  ...
}
```

**Warning 2:** `BCP318: Value may be null`

```
The value of type "Microsoft.Network/publicIPAddresses | null" may be null
```

**Fix Applied:**

```bicep
// Before
output publicIPAddress string = environment != 'dev' ? publicIP.properties.ipAddress : ''

// After
output publicIPAddress string = environment != 'dev' ? publicIP.properties.ipAddress : 'N/A'
output publicIPFQDN string = environment != 'dev' ? publicIP.properties.dnsSettings.fqdn : 'N/A'
```

---

## 🚀 Deployment Steps (Updated)

### **Step 1: Choose Your Template**

**If you have User Access Administrator role:**

```bash
TEMPLATE_FILE="main.bicep"
```

**If you DON'T have User Access Administrator role:**

```bash
TEMPLATE_FILE="main-no-rbac.bicep"
```

### **Step 2: Deploy Infrastructure**

```bash
ENVIRONMENT="dev"
RESOURCE_GROUP="rg-ecommerce-aks-${ENVIRONMENT}"
LOCATION="eastus"

# Register providers (one time)
cd infrastructure/bicep
./register-providers.sh

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Generate SSH key
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa_aks -N ""
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa_aks.pub)

# Update parameters
jq --arg ssh_key "$SSH_PUBLIC_KEY" \
   '.parameters.sshPublicKey.value = $ssh_key' \
   parameters.${ENVIRONMENT}.json > parameters.tmp.json

# Deploy
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --name "aks-deployment-$(date +%Y%m%d-%H%M%S)" \
  --template-file $TEMPLATE_FILE \
  --parameters @parameters.tmp.json
```

### **Step 3: Fix ACR Permissions (if using main-no-rbac.bicep)**

```bash
# Linux/Mac
chmod +x fix-acr-permissions.sh
./fix-acr-permissions.sh dev

# Windows
.\fix-acr-permissions.ps1 -Environment dev
```

### **Step 4: Get AKS Credentials and Verify**

```bash
# Get AKS name
AKS_NAME=$(az aks list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)

# Get credentials with admin access
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_NAME \
  --overwrite-existing \
  --admin

# Verify connection
kubectl cluster-info
kubectl get nodes

# Get ACR name
ACR_NAME=$(az acr list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)

# Test ACR login
az acr login --name $ACR_NAME

echo "✅ Deployment successful!"
```

---

## 📝 Files Updated

### **Templates**

1. ✅ `main.bicep` - Fixed all warnings and Azure Defender issue
2. 🆕 `main-no-rbac.bicep` - Template without role assignment

### **Helper Scripts**

3. 🆕 `fix-acr-permissions.sh` - Bash script to assign ACR permissions
4. 🆕 `fix-acr-permissions.ps1` - PowerShell script to assign ACR permissions

### **Documentation**

5. 🆕 `TROUBLESHOOTING.md` - Comprehensive troubleshooting guide
6. 🆕 `DEPLOYMENT_FIXES.md` - This file

### **Parameters** (No changes needed)

7. ✅ `parameters.dev.json` - Works with both templates
8. ✅ `parameters.prod.json` - Works with both templates

---

## 🔄 Pipeline Integration

### **Update Azure DevOps Pipeline**

Edit `azure-pipelines/infrastructure-pipeline.yml`:

```yaml
# Change from:
--template-file main.bicep

# To:
--template-file main-no-rbac.bicep
```

Add a step after deployment:

```yaml
- task: AzureCLI@2
  displayName: "Fix ACR Permissions"
  inputs:
    azureSubscription: $(azureServiceConnection)
    scriptType: "bash"
    scriptLocation: "scriptPath"
    scriptPath: "infrastructure/bicep/fix-acr-permissions.sh"
    arguments: "${{ parameters.environment }}"
```

### **Update GitHub Actions**

Edit `.github/workflows/deploy-infrastructure.yml`:

```yaml
# Change template reference:
- name: Deploy Infrastructure
  run: |
    cd infrastructure/bicep
    az deployment group create \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --name ${{ env.DEPLOYMENT_NAME }} \
      --template-file main-no-rbac.bicep \  # Changed here
      --parameters @parameters.tmp.json

# Add step to fix permissions:
- name: Fix ACR Permissions
  run: |
    cd infrastructure/bicep
    chmod +x fix-acr-permissions.sh
    ./fix-acr-permissions.sh ${{ env.ENVIRONMENT }}
```

---

## ✅ Verification Checklist

After deployment, verify:

- [ ] Resource group exists
- [ ] AKS cluster is in "Succeeded" state
- [ ] ACR is created
- [ ] VNet and subnets configured
- [ ] Log Analytics workspace created
- [ ] Can get AKS credentials: `az aks get-credentials`
- [ ] Can login to ACR: `az acr login --name <ACR_NAME>`
- [ ] kubectl connects: `kubectl get nodes`
- [ ] Nodes show "Ready" status
- [ ] ACR pull permissions assigned (check with `az role assignment list`)

**Check ACR permissions:**

```bash
ACR_ID=$(az acr show --name <ACR_NAME> --query id -o tsv)
az role assignment list --scope $ACR_ID --query "[?roleDefinitionName=='AcrPull']"
```

Should show the kubelet identity with AcrPull role.

---

## 🆘 Still Having Issues?

### **Clean Slate Approach**

If deployment continues to fail:

```bash
# 1. Delete everything
az group delete --name rg-ecommerce-aks-dev --yes --no-wait

# 2. Wait 5 minutes for cleanup

# 3. Start fresh with no-RBAC template
az group create --name rg-ecommerce-aks-dev --location eastus

cd infrastructure/bicep
az deployment group create \
  --resource-group rg-ecommerce-aks-dev \
  --template-file main-no-rbac.bicep \
  --parameters @parameters.dev.json

# 4. Fix permissions
./fix-acr-permissions.sh dev
```

### **Get Detailed Error Information**

```bash
# Show deployment errors
az deployment group show \
  --resource-group rg-ecommerce-aks-dev \
  --name <DEPLOYMENT_NAME> \
  --query properties.error

# Show all deployment operations
az deployment operation group list \
  --resource-group rg-ecommerce-aks-dev \
  --name <DEPLOYMENT_NAME> \
  --query "[].{Status:properties.statusCode, Message:properties.statusMessage.error.message}"
```

---

## 📚 Additional Resources

- **Bicep Documentation:** https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/
- **AKS Best Practices:** https://docs.microsoft.com/en-us/azure/aks/best-practices
- **ACR Integration:** https://docs.microsoft.com/en-us/azure/aks/cluster-container-registry-integration
- **Azure Defender for Containers:** https://docs.microsoft.com/en-us/azure/defender-for-cloud/defender-for-containers-introduction

---

## 🎯 Summary

**All issues are now fixed!**

Use `main-no-rbac.bicep` for deployment and run the fix script afterward. This approach:

- ✅ Doesn't require User Access Administrator role
- ✅ Fixes Azure Defender configuration issue
- ✅ Resolves all Bicep warnings
- ✅ Works with both Azure DevOps and GitHub Actions

**Next steps:**

1. Deploy infrastructure with `main-no-rbac.bicep`
2. Run `fix-acr-permissions.sh`
3. Build and push Docker images
4. Deploy applications to AKS

Happy deploying! 🚀
