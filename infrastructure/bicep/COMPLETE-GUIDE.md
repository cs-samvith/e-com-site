# Complete Deployment Guide - From Zero to Production

This is the definitive guide to deploy your e-commerce microservices to Azure Kubernetes Service (AKS).

---

## 📚 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Common Issues & Solutions](#common-issues--solutions)
3. [Step-by-Step Deployment](#step-by-step-deployment)
4. [Verification](#verification)
5. [Next Steps](#next-steps)

---

## Prerequisites

### Required Tools

- ✅ Azure CLI installed
- ✅ kubectl installed
- ✅ Docker installed (for building images)
- ✅ bash/PowerShell terminal
- ✅ jq (for JSON processing)

### Azure Requirements

- ✅ Active Azure subscription
- ✅ Permissions to create resources (Contributor role minimum)
- ✅ Resource providers registered (we'll do this in Step 1)

---

## Common Issues & Solutions

### ❌ Issue 1: MissingSubscriptionRegistration

**Error:** `The subscription is not registered to use namespace 'Microsoft.OperationsManagement'`

**Fix:** Run `./register-providers.sh` before deployment

---

### ❌ Issue 2: Authorization Failed for Role Assignment

**Error:** `doesn't have permission to perform action 'Microsoft.Authorization/roleAssignments/write'`

**Fix:** Use `main-no-rbac.bicep` instead of `main.bicep`

---

### ❌ Issue 3: Azure Defender Configuration Error

**Error:** `AzureDefender is disabled but Log Analytics workspace resource ID is not empty`

**Fix:** Already fixed in latest templates

---

### ❌ Issue 4: kubectl Connection Refused

**Error:** `The connection to the server localhost:8080 was refused`

**Fix:**

```bash
az aks get-credentials \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev \
  --overwrite-existing \
  --admin
```

---

## Step-by-Step Deployment

### Step 1: Register Azure Providers (2 minutes)

**This is REQUIRED before your first deployment.**

```bash
cd infrastructure/bicep

# Linux/Mac
chmod +x register-providers.sh
./register-providers.sh

# Windows
.\register-providers.ps1
```

**What this does:**

- Registers Microsoft.OperationsManagement
- Registers Microsoft.OperationalInsights
- Registers Microsoft.ContainerService
- Registers Microsoft.ContainerRegistry
- And other required providers

**Wait 1-2 minutes** for registration to complete.

---

### Step 2: Deploy Infrastructure (10-12 minutes)

**Using the automated script:**

```bash
# Linux/Mac
chmod +x deploy.sh
./deploy.sh dev

# Windows
.\deploy.ps1 -Environment dev
```

**Or manually:**

```bash
# Login to Azure
az login

# Set variables
ENVIRONMENT="dev"
RESOURCE_GROUP="rg-ecommerce-aks-${ENVIRONMENT}"
LOCATION="eastus"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Generate SSH key (if you don't have one)
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa_aks -N ""
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa_aks.pub)

# Update parameters file
cd infrastructure/bicep
jq --arg ssh_key "$SSH_PUBLIC_KEY" \
   '.parameters.sshPublicKey.value = $ssh_key' \
   parameters.${ENVIRONMENT}.json > parameters.tmp.json

# Deploy using no-RBAC template (recommended)
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --name "aks-deploy-$(date +%Y%m%d-%H%M%S)" \
  --template-file main-no-rbac.bicep \
  --parameters @parameters.tmp.json
```

**This creates:**

- ✅ AKS cluster (2 nodes, auto-scaling 1-5)
- ✅ Azure Container Registry
- ✅ Virtual Network with subnets
- ✅ Log Analytics workspace
- ✅ System-assigned managed identity

---

### Step 3: Fix ACR Permissions (30 seconds)

**Required if you used `main-no-rbac.bicep`:**

```bash
# Linux/Mac
chmod +x fix-acr-permissions.sh
./fix-acr-permissions.sh dev

# Windows
.\fix-acr-permissions.ps1 -Environment dev
```

**What this does:**

- Assigns `AcrPull` role to AKS kubelet identity
- Allows AKS to pull images from ACR

---

### Step 4: Verify Deployment (1 minute)

```bash
# Linux/Mac
chmod +x verify-deployment.sh
./verify-deployment.sh dev

# Windows
.\verify-deployment.ps1 -Environment dev
```

**This checks:**

- ✅ Resource group exists
- ✅ AKS cluster is running
- ✅ Nodes are ready
- ✅ ACR is accessible
- ✅ kubectl can connect
- ✅ ACR permissions are set

---

## Verification

### Manual Verification

```bash
# 1. Get cluster info
az aks list --resource-group rg-ecommerce-aks-dev --output table

# 2. Get AKS credentials with admin access
az aks get-credentials \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev \
  --overwrite-existing \
  --admin

# 3. Check nodes
kubectl get nodes

# Should show 2 nodes in "Ready" status

# 4. Check system pods
kubectl get pods -n kube-system

# All pods should be Running

# 5. Test ACR
ACR_NAME=$(az acr list --resource-group rg-ecommerce-aks-dev --query "[0].name" -o tsv)
az acr login --name $ACR_NAME

# Should say "Login Succeeded"
```

---

## Next Steps

### 1. Build and Push Docker Images

```bash
# Get ACR login server
ACR_NAME=$(az acr list --resource-group rg-ecommerce-aks-dev --query "[0].name" -o tsv)
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

# Login to ACR
az acr login --name $ACR_NAME

# Build and push product service
cd services/product-service
docker build -t ${ACR_LOGIN_SERVER}/product-service:latest .
docker push ${ACR_LOGIN_SERVER}/product-service:latest

# Build and push user service
cd ../user-service
docker build -t ${ACR_LOGIN_SERVER}/user-service:latest .
docker push ${ACR_LOGIN_SERVER}/user-service:latest

# Build and push frontend service
cd ../frontend-service
docker build -t ${ACR_LOGIN_SERVER}/frontend-service:latest .
docker push ${ACR_LOGIN_SERVER}/frontend-service:latest
```

### 2. Update Kubernetes Manifests

```bash
cd ../../kubernetes/services

# Update deployment files with your ACR name
find . -name "deployment.yaml" -exec sed -i "s|<YOUR_ACR>|$ACR_NAME|g" {} +

# Verify changes
grep -r "image:" .
```

### 3. Deploy Applications to AKS

```bash
cd ../..

# Deploy namespace and secrets
kubectl apply -f kubernetes/base/

# Deploy data layer (PostgreSQL, Redis, RabbitMQ)
kubectl apply -f kubernetes/data-layer/

# Wait for data layer to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n ecommerce --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n ecommerce --timeout=120s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n ecommerce --timeout=300s

# Deploy microservices
kubectl apply -f kubernetes/services/

# Wait for services to be ready
kubectl wait --for=condition=ready pod -l app=product-service -n ecommerce --timeout=300s
kubectl wait --for=condition=ready pod -l app=user-service -n ecommerce --timeout=300s
kubectl wait --for=condition=ready pod -l app=frontend-service -n ecommerce --timeout=300s

# Deploy ingress
kubectl apply -f kubernetes/ingress/
```

### 4. Check Deployment Status

```bash
# View all resources
kubectl get all -n ecommerce

# Check pods
kubectl get pods -n ecommerce

# Check services
kubectl get svc -n ecommerce

# Check ingress
kubectl get ingress -n ecommerce

# Get application URL
INGRESS_IP=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Application URL: http://$INGRESS_IP"
```

### 5. Test the Application

```bash
# Test product service
curl http://$INGRESS_IP/api/products

# Test user service
curl http://$INGRESS_IP/api/users

# Access frontend
open http://$INGRESS_IP
```

---

## Cleanup

### Stop Cluster (Save Money)

```bash
# Stop cluster (keeps resources, stops billing for VMs)
az aks stop \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev

# Start when needed
az aks start \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev
```

### Delete Everything

```bash
# Delete entire resource group (WARNING: Deletes everything!)
az group delete \
  --name rg-ecommerce-aks-dev \
  --yes \
  --no-wait
```

---

## Troubleshooting

### Get Deployment Errors

```bash
# List all deployments
az deployment group list \
  --resource-group rg-ecommerce-aks-dev \
  --output table

# Get error details
az deployment group show \
  --resource-group rg-ecommerce-aks-dev \
  --name <DEPLOYMENT_NAME> \
  --query properties.error
```

### Check AKS Cluster Health

```bash
# Get cluster status
az aks show \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev \
  --query "{Status: provisioningState, Fqdn: fqdn, K8sVersion: kubernetesVersion}"

# Check node status
kubectl get nodes -o wide

# Check all pods
kubectl get pods --all-namespaces
```

### View Logs

```bash
# Pod logs
kubectl logs <POD_NAME> -n ecommerce

# Follow logs
kubectl logs -f <POD_NAME> -n ecommerce

# Previous container logs (if pod restarted)
kubectl logs <POD_NAME> -n ecommerce --previous
```

---

## Reference Documents

- **Quick Start:** `QUICK_START.md` - 15-minute deployment
- **Troubleshooting:** `TROUBLESHOOTING.md` - Common issues and solutions
- **Deployment Fixes:** `DEPLOYMENT_FIXES.md` - All fixes applied
- **Bicep Details:** `README.md` - Infrastructure as code details

---

## Scripts Available

| Script                    | Purpose                  | Platform  |
| ------------------------- | ------------------------ | --------- |
| `register-providers.sh`   | Register Azure providers | Linux/Mac |
| `register-providers.ps1`  | Register Azure providers | Windows   |
| `deploy.sh`               | Deploy infrastructure    | Linux/Mac |
| `deploy.ps1`              | Deploy infrastructure    | Windows   |
| `fix-acr-permissions.sh`  | Fix ACR permissions      | Linux/Mac |
| `fix-acr-permissions.ps1` | Fix ACR permissions      | Windows   |
| `verify-deployment.sh`    | Verify deployment        | Linux/Mac |
| `verify-deployment.ps1`   | Verify deployment        | Windows   |

---

## Success Checklist

- [ ] Azure providers registered
- [ ] Infrastructure deployed successfully
- [ ] ACR permissions configured
- [ ] kubectl can connect to cluster
- [ ] All nodes are Ready
- [ ] Docker images built and pushed to ACR
- [ ] Kubernetes manifests updated with ACR name
- [ ] Applications deployed to AKS
- [ ] All pods are Running
- [ ] Ingress has external IP
- [ ] Application is accessible

---

## Support

If you encounter issues:

1. Check `TROUBLESHOOTING.md` first
2. Run `verify-deployment.sh` to diagnose
3. Check Azure Portal → Resource Group → Deployments for errors
4. Review logs with `kubectl logs`

---

**You're all set! Happy deploying! 🚀**
