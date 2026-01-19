#!/bin/bash

# Verify AKS Deployment
# Run this after deployment to check everything is working

set -e

ENVIRONMENT=${1:-dev}
RESOURCE_GROUP="rg-ecommerce-aks-${ENVIRONMENT}"

echo "========================================="
echo "Verify AKS Deployment"
echo "========================================="
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo ""

# Check Azure login
az account show &> /dev/null || {
    echo "❌ Not logged in to Azure. Please run 'az login'"
    exit 1
}

echo "✅ Logged in to Azure"
echo ""

# Check if resource group exists
if ! az group show --name $RESOURCE_GROUP &> /dev/null; then
    echo "❌ Resource group $RESOURCE_GROUP not found"
    exit 1
fi
echo "✅ Resource group exists"

# Get AKS cluster
AKS_NAME=$(az aks list \
    --resource-group $RESOURCE_GROUP \
    --query "[0].name" \
    --output tsv)

if [ -z "$AKS_NAME" ]; then
    echo "❌ AKS cluster not found"
    exit 1
fi
echo "✅ AKS cluster found: $AKS_NAME"

# Check AKS status
PROVISIONING_STATE=$(az aks show \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_NAME \
    --query provisioningState \
    --output tsv)

if [ "$PROVISIONING_STATE" != "Succeeded" ]; then
    echo "❌ AKS cluster not ready. Status: $PROVISIONING_STATE"
    exit 1
fi
echo "✅ AKS cluster status: $PROVISIONING_STATE"

# Get ACR
ACR_NAME=$(az acr list \
    --resource-group $RESOURCE_GROUP \
    --query "[0].name" \
    --output tsv)

if [ -z "$ACR_NAME" ]; then
    echo "❌ ACR not found"
    exit 1
fi
echo "✅ ACR found: $ACR_NAME"

# Get AKS credentials
echo ""
echo "Getting AKS credentials..."
az aks get-credentials \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_NAME \
    --overwrite-existing \
    --admin &> /dev/null

echo "✅ AKS credentials configured"

# Test kubectl connection
echo ""
echo "Testing kubectl connection..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to cluster with kubectl"
    echo "Try running: az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --overwrite-existing --admin"
    exit 1
fi
echo "✅ kubectl connected to cluster"

# Check nodes
echo ""
echo "Checking nodes..."
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c Ready || echo 0)

if [ "$NODE_COUNT" -eq 0 ]; then
    echo "❌ No nodes found"
    exit 1
fi

echo "✅ Nodes: $NODE_COUNT total, $READY_COUNT ready"
kubectl get nodes

# Check ACR integration
echo ""
echo "Checking ACR integration..."
KUBELET_IDENTITY=$(az aks show \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_NAME \
    --query identityProfile.kubeletidentity.objectId \
    --output tsv)

ACR_ID=$(az acr show \
    --name $ACR_NAME \
    --query id \
    --output tsv)

ROLE_ASSIGNED=$(az role assignment list \
    --assignee $KUBELET_IDENTITY \
    --scope $ACR_ID \
    --query "[?roleDefinitionName=='AcrPull'].roleDefinitionName" \
    --output tsv)

if [ -z "$ROLE_ASSIGNED" ]; then
    echo "⚠️  ACR pull role not assigned"
    echo "Run: ./fix-acr-permissions.sh $ENVIRONMENT"
else
    echo "✅ ACR pull role assigned"
fi

# Test ACR login
echo ""
echo "Testing ACR login..."
if az acr login --name $ACR_NAME &> /dev/null; then
    echo "✅ ACR login successful"
else
    echo "❌ ACR login failed"
fi

# Check Log Analytics
echo ""
echo "Checking Log Analytics..."
LAW_NAME=$(az monitor log-analytics workspace list \
    --resource-group $RESOURCE_GROUP \
    --query "[0].name" \
    --output tsv)

if [ -z "$LAW_NAME" ]; then
    echo "⚠️  Log Analytics workspace not found"
else
    echo "✅ Log Analytics workspace: $LAW_NAME"
fi

# Summary
echo ""
echo "========================================="
echo "Deployment Verification Summary"
echo "========================================="
echo ""
echo "✅ Resource Group: $RESOURCE_GROUP"
echo "✅ AKS Cluster: $AKS_NAME ($PROVISIONING_STATE)"
echo "✅ Nodes: $NODE_COUNT ($READY_COUNT ready)"
echo "✅ ACR: $ACR_NAME"
if [ -n "$ROLE_ASSIGNED" ]; then
    echo "✅ ACR Integration: Configured"
else
    echo "⚠️  ACR Integration: Needs configuration"
fi
if [ -n "$LAW_NAME" ]; then
    echo "✅ Log Analytics: $LAW_NAME"
fi
echo ""

# Next steps
echo "========================================="
echo "Next Steps"
echo "========================================="
echo ""

if [ -z "$ROLE_ASSIGNED" ]; then
    echo "1. Fix ACR permissions:"
    echo "   ./fix-acr-permissions.sh $ENVIRONMENT"
    echo ""
fi

echo "2. Build and push images:"
echo "   az acr login --name $ACR_NAME"
echo "   docker build -t $ACR_NAME.azurecr.io/product-service:latest services/product-service"
echo "   docker push $ACR_NAME.azurecr.io/product-service:latest"
echo ""

echo "3. Deploy applications:"
echo "   kubectl apply -f kubernetes/base/"
echo "   kubectl apply -f kubernetes/data-layer/"
echo "   kubectl apply -f kubernetes/services/"
echo ""

echo "4. Check deployment:"
echo "   kubectl get pods -n ecommerce"
echo ""

echo "✅ Verification complete!"