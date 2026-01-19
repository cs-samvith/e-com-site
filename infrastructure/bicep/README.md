# AKS Infrastructure as Code - Bicep

This directory contains Bicep templates to deploy Azure Kubernetes Service (AKS) infrastructure for the e-commerce microservices application.

---

## 📁 Files

- **`main.bicep`** - Main Bicep template (AKS cluster, ACR, VNet, monitoring)
- **`parameters.dev.json`** - Development environment parameters
- **`parameters.prod.json`** - Production environment parameters
- **`deploy.sh`** - Bash deployment script (Linux/Mac)
- **`deploy.ps1`** - PowerShell deployment script (Windows)
- **`README.md`** - This file

---

## 🏗️ Infrastructure Components

The Bicep template deploys:

1. **Azure Kubernetes Service (AKS)**
   - System-assigned managed identity
   - Auto-scaling enabled
   - Azure CNI networking
   - RBAC enabled
2. **Azure Container Registry (ACR)**
   - Integrated with AKS
   - Role assignment for AKS to pull images
3. **Virtual Network**
   - AKS subnet (10.0.0.0/22)
   - Application Gateway subnet (10.0.4.0/24)
4. **Log Analytics Workspace**
   - For monitoring and diagnostics
   - 30-day retention
5. **Public IP** (staging/prod only)
   - For Application Gateway

---

## 📊 Environment Configurations

### Development (dev)

- **VM Size:** Standard_B2ms (2 vCPU, 8GB RAM)
- **Node Count:** 2 (min: 1, max: 5)
- **ACR SKU:** Basic
- **Availability Zones:** No
- **Estimated Cost:** ~$100-120/month

### Production (prod)

- **VM Size:** Standard_D2s_v3 (2 vCPU, 8GB RAM)
- **Node Count:** 3 (min: 3, max: 10)
- **ACR SKU:** Standard
- **Availability Zones:** Yes (1, 2, 3)
- **Estimated Cost:** ~$350-400/month

---

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI** installed

   ```bash
   # Install on Windows
   winget install Microsoft.AzureCLI

   # Install on Linux/Mac
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```

2. **kubectl** installed

   ```bash
   az aks install-cli
   ```

3. **Azure subscription** with permissions to create resources

---

## 📝 Deployment Steps

### 1. Login to Azure

```bash
az login
az account set --subscription <YOUR_SUBSCRIPTION_ID>
```

### 2. Update SSH Public Key

Generate SSH key if you don't have one:

```bash
# Linux/Mac
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa_aks

# Windows PowerShell
ssh-keygen -t rsa -b 2048 -f $env:USERPROFILE\.ssh\id_rsa_aks
```

The deployment scripts will automatically use this key.

### 3. Deploy Using Scripts

**For Windows (PowerShell):**

```powershell
cd infrastructure/bicep
.\deploy.ps1 -Environment dev
```

**For Linux/Mac (Bash):**

```bash
cd infrastructure/bicep
chmod +x deploy.sh
./deploy.sh dev
```

**For Production:**

```powershell
# Windows
.\deploy.ps1 -Environment prod

# Linux/Mac
./deploy.sh prod
```

---

## 🛠️ Manual Deployment (Without Scripts)

### 1. Create Resource Group

```bash
ENVIRONMENT="dev"
RESOURCE_GROUP="rg-ecommerce-aks-${ENVIRONMENT}"
LOCATION="eastus"

az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 2. Update Parameters File

Edit `parameters.dev.json` or `parameters.prod.json`:

- Update `sshPublicKey` with your SSH public key
- Optionally change location, names, etc.

### 3. Validate Template

```bash
az deployment group validate \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters @parameters.dev.json
```

### 4. Deploy Template

```bash
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --name "aks-deployment-$(date +%Y%m%d-%H%M%S)" \
  --template-file main.bicep \
  --parameters @parameters.dev.json
```

This will take 10-15 minutes.

### 5. Get AKS Credentials

```bash
AKS_NAME=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name <DEPLOYMENT_NAME> \
  --query 'properties.outputs.aksClusterName.value' \
  --output tsv)

az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_NAME
```

### 6. Verify Cluster

```bash
kubectl get nodes
kubectl cluster-info
```

---

## 📤 Deploy Applications

After infrastructure is deployed:

### 1. Login to ACR and Push Images

```bash
ACR_NAME=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name <DEPLOYMENT_NAME> \
  --query 'properties.outputs.acrName.value' \
  --output tsv)

ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)

az acr login --name $ACR_NAME

# Build and push images
cd ../../services
docker build -t $ACR_LOGIN_SERVER/product-service:latest product-service
docker build -t $ACR_LOGIN_SERVER/user-service:latest user-service
docker build -t $ACR_LOGIN_SERVER/frontend-service:latest frontend-service

docker push $ACR_LOGIN_SERVER/product-service:latest
docker push $ACR_LOGIN_SERVER/user-service:latest
docker push $ACR_LOGIN_SERVER/frontend-service:latest
```

### 2. Update Kubernetes Manifests

Update image references in deployment files:

```bash
cd ../../kubernetes/services

# Replace <YOUR_ACR> with actual ACR name
find . -name "deployment.yaml" -exec sed -i "s|<YOUR_ACR>|$ACR_NAME|g" {} +
```

### 3. Deploy to Kubernetes

```bash
cd ../..
kubectl apply -f kubernetes/base/
kubectl apply -f kubernetes/data-layer/
kubectl apply -f kubernetes/services/
kubectl apply -f kubernetes/ingress/
```

### 4. Monitor Deployment

```bash
kubectl get pods -n ecommerce -w
kubectl get svc -n ecommerce
kubectl get ingress -n ecommerce
```

---

## 🔍 Verification

### Check All Resources

```bash
# List all resources in resource group
az resource list --resource-group $RESOURCE_GROUP --output table

# Check AKS cluster
az aks show --resource-group $RESOURCE_GROUP --name $AKS_NAME

# Check ACR
az acr show --name $ACR_NAME

# Check node pools
az aks nodepool list --resource-group $RESOURCE_GROUP --cluster-name $AKS_NAME
```

### Check Kubernetes Resources

```bash
# All namespaces
kubectl get all --all-namespaces

# Ecommerce namespace
kubectl get all -n ecommerce

# Describe a pod
kubectl describe pod <POD_NAME> -n ecommerce

# View logs
kubectl logs -f <POD_NAME> -n ecommerce
```

---

## 🔄 Updates and Modifications

### Update AKS Cluster

Modify `main.bicep` and redeploy:

```bash
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --name "aks-update-$(date +%Y%m%d-%H%M%S)" \
  --template-file main.bicep \
  --parameters @parameters.dev.json
```

Bicep will only update changed resources.

### Scale Node Pool

```bash
az aks scale \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_NAME \
  --node-count 3
```

### Upgrade Kubernetes Version

```bash
# Check available versions
az aks get-upgrades --resource-group $RESOURCE_GROUP --name $AKS_NAME

# Upgrade cluster
az aks upgrade \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_NAME \
  --kubernetes-version 1.28.3
```

---

## 🗑️ Cleanup

### Delete Applications Only

```bash
kubectl delete namespace ecommerce
```

### Delete Entire Infrastructure

```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

**Warning:** This deletes everything including data!

---

## 💰 Cost Management

### View Costs

```bash
# Current month cost
az consumption usage list \
  --start-date $(date -d "$(date +%Y-%m-01)" +%Y-%m-%d) \
  --end-date $(date +%Y-%m-%d) \
  --query "[?contains(instanceName,'$RESOURCE_GROUP')].{Service:meterName,Cost:pretaxCost}" \
  --output table
```

### Stop Cluster (Save Costs)

```bash
# Stop AKS (stops VMs but keeps resources)
az aks stop --resource-group $RESOURCE_GROUP --name $AKS_NAME

# Start when needed
az aks start --resource-group $RESOURCE_GROUP --name $AKS_NAME
```

---

## 🐛 Troubleshooting

### Deployment Fails

```bash
# Check deployment errors
az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name <DEPLOYMENT_NAME> \
  --query 'properties.error'

# View deployment operations
az deployment operation group list \
  --resource-group $RESOURCE_GROUP \
  --name <DEPLOYMENT_NAME>
```

### AKS Cluster Issues

```bash
# Check cluster health
az aks show --resource-group $RESOURCE_GROUP --name $AKS_NAME

# View cluster diagnostics
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME
kubectl get componentstatuses

# Check node logs
kubectl describe nodes
```

### ACR Access Issues

```bash
# Verify role assignment
az role assignment list \
  --scope $(az acr show --name $ACR_NAME --query id --output tsv)

# Test ACR access from AKS
kubectl run test-acr --image=$ACR_LOGIN_SERVER/product-service:latest -n ecommerce
```

---

## 📚 Additional Resources

- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [ACR Documentation](https://docs.microsoft.com/en-us/azure/container-registry/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

## ✅ Deployment Checklist

- [ ] Azure CLI installed
- [ ] kubectl installed
- [ ] Logged in to Azure
- [ ] SSH key generated
- [ ] Parameters file updated
- [ ] Resource group created
- [ ] Bicep template validated
- [ ] Infrastructure deployed
- [ ] AKS credentials obtained
- [ ] Cluster access verified
- [ ] Docker images built and pushed
- [ ] Kubernetes manifests updated
- [ ] Applications deployed
- [ ] Ingress configured
- [ ] Monitoring enabled

---

For any issues or questions, refer to the troubleshooting section or the Azure documentation.
