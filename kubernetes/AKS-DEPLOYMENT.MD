# Azure Kubernetes Service (AKS) Deployment Guide

Complete guide to deploy the e-commerce microservices to Azure Kubernetes Service.

---

## 📋 Prerequisites

1. **Azure Account** with active subscription
2. **Azure CLI** installed (`az`)
3. **kubectl** installed
4. **Docker** installed (for building images)
5. **Helm** (optional, for easier deployments)

---

## 🚀 Part 1: Azure Infrastructure Setup

### 1. Login to Azure

```bash
az login
az account set --subscription <YOUR_SUBSCRIPTION_ID>
```

### 2. Create Resource Group

```bash
# Set variables
RESOURCE_GROUP="rg-ecommerce-aks"
LOCATION="eastus"  # or your preferred location
AKS_CLUSTER_NAME="aks-ecommerce"
ACR_NAME="acrecommerce001"  # Must be globally unique, lowercase only

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 3. Create Azure Container Registry (ACR)

```bash
# Create ACR
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Standard \
  --location $LOCATION

# Login to ACR
az acr login --name $ACR_NAME

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)
echo "ACR Login Server: $ACR_LOGIN_SERVER"
```

### 4. Create AKS Cluster

```bash
# Create AKS cluster with ACR integration
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --node-count 3 \
  --node-vm-size Standard_D2s_v3 \
  --enable-managed-identity \
  --attach-acr $ACR_NAME \
  --network-plugin azure \
  --enable-addons monitoring,ingress-appgw \
  --appgw-name ecommerce-appgw \
  --appgw-subnet-cidr "10.2.0.0/16" \
  --generate-ssh-keys

# This will take 5-10 minutes
```

### 5. Connect to AKS Cluster

```bash
# Get credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME

# Verify connection
kubectl get nodes
```

---

## 🐳 Part 2: Build and Push Docker Images

### 1. Navigate to Project Root

```bash
cd C:\mygit\e-com-site
```

### 2. Build and Push Product Service

```bash
cd services/product-service

# Build
docker build -t $ACR_LOGIN_SERVER/product-service:latest .
docker build -t $ACR_LOGIN_SERVER/product-service:v1.0.0 .

# Push
docker push $ACR_LOGIN_SERVER/product-service:latest
docker push $ACR_LOGIN_SERVER/product-service:v1.0.0

cd ../..
```

### 3. Build and Push User Service

```bash
cd services/user-service

# Build
docker build -t $ACR_LOGIN_SERVER/user-service:latest .
docker build -t $ACR_LOGIN_SERVER/user-service:v1.0.0 .

# Push
docker push $ACR_LOGIN_SERVER/user-service:latest
docker push $ACR_LOGIN_SERVER/user-service:v1.0.0

cd ../..
```

### 4. Build and Push Frontend Service

```bash
cd services/frontend-service

# Build (using the Dockerfile we just created)
docker build -t $ACR_LOGIN_SERVER/frontend-service:latest .
docker build -t $ACR_LOGIN_SERVER/frontend-service:v1.0.0 .

# Push
docker push $ACR_LOGIN_SERVER/frontend-service:latest
docker push $ACR_LOGIN_SERVER/frontend-service:v1.0.0

cd ../..
```

### 5. Verify Images in ACR

```bash
az acr repository list --name $ACR_NAME --output table
```

---

## 📝 Part 3: Update Kubernetes Manifests

### Update Image References

Replace `<YOUR_ACR>` with your ACR name in these files:

1. **kubernetes/services/product-service/deployment.yaml**

   ```yaml
   image: <YOUR_ACR>.azurecr.io/product-service:latest
   ```

2. **kubernetes/services/user-service/deployment.yaml**

   ```yaml
   image: <YOUR_ACR>.azurecr.io/user-service:latest
   ```

3. **kubernetes/services/frontend-service/deployment.yaml**
   ```yaml
   image: <YOUR_ACR>.azurecr.io/frontend-service:latest
   ```

**Quick Replace Script:**

```bash
# Linux/Mac
find kubernetes/services -name "deployment.yaml" -exec sed -i "s|<YOUR_ACR>|$ACR_NAME|g" {} +

# Windows (PowerShell)
Get-ChildItem -Path kubernetes\services -Filter deployment.yaml -Recurse |
  ForEach-Object {
    (Get-Content $_.FullName) -replace '<YOUR_ACR>', $ACR_NAME |
    Set-Content $_.FullName
  }
```

---

## 🔐 Part 4: Create Secrets

### Generate Strong Passwords

```bash
# Generate strong passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
RABBITMQ_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 32)

echo "Save these securely!"
echo "POSTGRES_PASSWORD: $POSTGRES_PASSWORD"
echo "RABBITMQ_PASSWORD: $RABBITMQ_PASSWORD"
echo "JWT_SECRET: $JWT_SECRET"
```

### Create Namespace

```bash
kubectl apply -f kubernetes/base/namespace.yaml
```

### Create Database Secrets

```bash
kubectl create secret generic database-secrets \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  --from-literal=POSTGRES_HOST=postgres-service \
  --from-literal=POSTGRES_PORT=5432 \
  --from-literal=PRODUCT_DB_NAME=products_db \
  --from-literal=PRODUCT_DB_USER=postgres \
  --from-literal=PRODUCT_DB_PASSWORD=$POSTGRES_PASSWORD \
  --from-literal=USER_DB_NAME=users_db \
  --from-literal=USER_DB_USER=postgres \
  --from-literal=USER_DB_PASSWORD=$POSTGRES_PASSWORD \
  --from-literal=REDIS_HOST=redis-service \
  --from-literal=REDIS_PORT=6379 \
  --from-literal=RABBITMQ_HOST=rabbitmq-service \
  --from-literal=RABBITMQ_PORT=5672 \
  --from-literal=RABBITMQ_USER=admin \
  --from-literal=RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD \
  -n ecommerce
```

### Create JWT Secrets

```bash
kubectl create secret generic jwt-secrets \
  --from-literal=JWT_SECRET=$JWT_SECRET \
  --from-literal=JWT_ALGORITHM=HS256 \
  -n ecommerce
```

### Verify Secrets

```bash
kubectl get secrets -n ecommerce
```

---

## 📊 Part 5: Deploy Data Layer

### Deploy PostgreSQL

```bash
kubectl apply -f kubernetes/data-layer/postgres/

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n ecommerce --timeout=300s

# Check logs
kubectl logs -f -l app=postgres -n ecommerce
```

### Deploy Redis

```bash
kubectl apply -f kubernetes/data-layer/redis/

# Wait for Redis to be ready
kubectl wait --for=condition=ready pod -l app=redis -n ecommerce --timeout=120s
```

### Deploy RabbitMQ

```bash
kubectl apply -f kubernetes/data-layer/rabbitmq/

# Wait for RabbitMQ to be ready
kubectl wait --for=condition=ready pod -l app=rabbitmq -n ecommerce --timeout=300s
```

### Verify Data Layer

```bash
kubectl get pods -n ecommerce
kubectl get pvc -n ecommerce
kubectl get svc -n ecommerce
```

---

## 🎯 Part 6: Deploy Microservices

### Deploy Product Service

```bash
kubectl apply -f kubernetes/services/product-service/

# Check deployment
kubectl get pods -l app=product-service -n ecommerce
kubectl logs -f -l app=product-service -n ecommerce
```

### Deploy User Service

```bash
kubectl apply -f kubernetes/services/user-service/

# Check deployment
kubectl get pods -l app=user-service -n ecommerce
kubectl logs -f -l app=user-service -n ecommerce
```

### Deploy Frontend Service

```bash
kubectl apply -f kubernetes/services/frontend-service/

# Check deployment
kubectl get pods -l app=frontend-service -n ecommerce
kubectl logs -f -l app=frontend-service -n ecommerce
```

### Verify All Services

```bash
kubectl get all -n ecommerce
```

---

## 🌐 Part 7: Configure Ingress (Application Gateway)

### Update Ingress with Your Domain

Edit `kubernetes/ingress/ingress.yaml` and replace `ecommerce.yourdomain.com` with your actual domain or Azure public IP.

### Deploy Ingress

```bash
kubectl apply -f kubernetes/ingress/ingress.yaml
```

### Get Application Gateway Public IP

```bash
# Get the public IP
kubectl get ingress -n ecommerce

# Or get from Azure
az network public-ip list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'appgw')].{Name:name, IP:ipAddress}" \
  --output table
```

### Configure DNS (Optional)

If you have a domain:

```bash
# Get the public IP
PUBLIC_IP=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Add A record in your DNS provider pointing to this IP
# Example: ecommerce.yourdomain.com -> $PUBLIC_IP
```

### Test Without Domain (Using IP)

```bash
# Get the IP
PUBLIC_IP=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test endpoints
curl http://$PUBLIC_IP/
curl http://$PUBLIC_IP/api/products
curl http://$PUBLIC_IP/api/users
```

---

## 📈 Part 8: Configure Monitoring (Optional but Recommended)

### Enable Azure Monitor for Containers

Already enabled if you used `--enable-addons monitoring` during AKS creation.

### View Logs in Azure Portal

1. Go to Azure Portal
2. Navigate to your AKS cluster
3. Click on "Logs" in the left menu
4. Run queries to view logs

### View Metrics

1. In Azure Portal → AKS cluster
2. Click on "Insights"
3. View cluster performance, pod metrics, etc.

---

## 🧪 Part 9: Testing

### Test Services Internally

```bash
# Port-forward to test
kubectl port-forward -n ecommerce svc/product-service 8081:8081 &
kubectl port-forward -n ecommerce svc/user-service 8080:8080 &
kubectl port-forward -n ecommerce svc/frontend-service 3000:3000 &

# Test
curl http://localhost:8081/health
curl http://localhost:8080/health
curl http://localhost:3000

# Kill port-forwards
pkill -f "port-forward"
```

### Test via Ingress

```bash
# Get public IP
PUBLIC_IP=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test frontend
curl http://$PUBLIC_IP/

# Test APIs
curl http://$PUBLIC_IP/api/products
curl http://$PUBLIC_IP/api/users
```

### Load Testing (Optional)

```bash
# Install hey (HTTP load testing tool)
# https://github.com/rakyll/hey

# Test product service
hey -n 1000 -c 50 http://$PUBLIC_IP/api/products

# Watch HPA scale
watch kubectl get hpa -n ecommerce
```

---

## 🔄 Part 10: CI/CD Setup (Optional)

### Using GitHub Actions

Create `.github/workflows/deploy-aks.yml`:

```yaml
name: Deploy to AKS

on:
  push:
    branches: [main]

env:
  AZURE_RESOURCE_GROUP: rg-ecommerce-aks
  AKS_CLUSTER_NAME: aks-ecommerce
  ACR_NAME: acrecommerce001

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Build and Push Images
        run: |
          az acr login --name $ACR_NAME

          # Product Service
          docker build -t $ACR_NAME.azurecr.io/product-service:${{ github.sha }} services/product-service
          docker push $ACR_NAME.azurecr.io/product-service:${{ github.sha }}

          # User Service
          docker build -t $ACR_NAME.azurecr.io/user-service:${{ github.sha }} services/user-service
          docker push $ACR_NAME.azurecr.io/user-service:${{ github.sha }}

          # Frontend Service
          docker build -t $ACR_NAME.azurecr.io/frontend-service:${{ github.sha }} services/frontend-service
          docker push $ACR_NAME.azurecr.io/frontend-service:${{ github.sha }}

      - name: Set AKS Context
        run: |
          az aks get-credentials \
            --resource-group $AZURE_RESOURCE_GROUP \
            --name $AKS_CLUSTER_NAME

      - name: Deploy to AKS
        run: |
          kubectl set image deployment/product-service product-service=$ACR_NAME.azurecr.io/product-service:${{ github.sha }} -n ecommerce
          kubectl set image deployment/user-service user-service=$ACR_NAME.azurecr.io/user-service:${{ github.sha }} -n ecommerce
          kubectl set image deployment/frontend-service frontend-service=$ACR_NAME.azurecr.io/frontend-service:${{ github.sha }} -n ecommerce
```

---

## 🔐 Part 11: Enable HTTPS/TLS (Production)

### Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### Create ClusterIssuer for Let's Encrypt

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: azure/application-gateway
```

### Update Ingress for HTTPS

Uncomment the TLS section in `kubernetes/ingress/ingress.yaml`

---

## 💰 Part 12: Cost Optimization

### Auto-shutdown Non-Production Clusters

```bash
# Stop AKS cluster (stops VM compute, keeps storage)
az aks stop --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP

# Start when needed
az aks start --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP
```

### Use Spot Instances (for dev/test)

```bash
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $AKS_CLUSTER_NAME \
  --name spotnodepool \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1 \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3
```

---

## 🗑️ Cleanup

### Delete Kubernetes Resources

```bash
# Delete services
kubectl delete -f kubernetes/services/

# Delete data layer
kubectl delete -f kubernetes/data-layer/

# Delete ingress
kubectl delete -f kubernetes/ingress/

# Delete namespace (removes everything)
kubectl delete namespace ecommerce
```

### Delete Azure Resources

```bash
# Delete entire resource group (CAUTION: Deletes everything)
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

---

## 🎯 Quick Deployment Script

Create `deploy-to-aks.sh`:

```bash
#!/bin/bash

# Variables
RESOURCE_GROUP="rg-ecommerce-aks"
AKS_CLUSTER_NAME="aks-ecommerce"
ACR_NAME="acrecommerce001"

# Get credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME

# Deploy everything
kubectl apply -f kubernetes/base/
kubectl apply -f kubernetes/data-layer/
kubectl apply -f kubernetes/services/
kubectl apply -f kubernetes/ingress/

# Wait and check
kubectl get pods -n ecommerce -w
```

---

## 📚 Useful Commands

```bash
# Check cluster info
az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME

# Scale node pool
az aks scale --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --node-count 5

# Upgrade AKS
az aks upgrade --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --kubernetes-version 1.28.3

# View AKS logs
az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query "addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID" -o tsv

# Get pod logs
kubectl logs -f <POD_NAME> -n ecommerce

# Describe pod
kubectl describe pod <POD_NAME> -n ecommerce

# Execute command in pod
kubectl exec -it <POD_NAME> -n ecommerce -- /bin/sh
```

---

## ✅ Success Checklist

- [ ] Azure resources created (RG, ACR, AKS)
- [ ] Docker images built and pushed to ACR
- [ ] Secrets created in Kubernetes
- [ ] Data layer deployed (PostgreSQL, Redis, RabbitMQ)
- [ ] All 3 services deployed (product, user, frontend)
- [ ] Ingress configured with Application Gateway
- [ ] Services accessible via public IP/domain
- [ ] Monitoring enabled in Azure Portal
- [ ] HPA working (check with load test)

---

Your microservices are now running on Azure Kubernetes Service! 🎉
