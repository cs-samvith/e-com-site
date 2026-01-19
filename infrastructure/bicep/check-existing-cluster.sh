#!/bin/bash

# Check if AKS cluster already exists
# Run this before deploying to avoid SSH key change errors

set -e

ENVIRONMENT=${1:-dev}
RESOURCE_GROUP="rg-ecommerce-aks-${ENVIRONMENT}"
AKS_NAME="aks-ecommerce-${ENVIRONMENT}"

echo "========================================="
echo "Check Existing Cluster"
echo "========================================="
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo ""

# Check Azure login
az account show &> /dev/null || {
    echo "❌ Not logged in to Azure. Please run 'az login'"
    exit 1
}

# Check if resource group exists
if ! az group show --name $RESOURCE_GROUP &> /dev/null; then
    echo "✅ Resource group does not exist - safe to deploy fresh"
    echo ""
    echo "Run: ./deploy.sh $ENVIRONMENT"
    exit 0
fi

echo "⚠️  Resource group exists: $RESOURCE_GROUP"

# Check if AKS cluster exists
if az aks show --resource-group $RESOURCE_GROUP --name $AKS_NAME &> /dev/null 2>&1; then
    echo "⚠️  AKS cluster exists: $AKS_NAME"
    echo ""
    
    # Get cluster details
    PROVISIONING_STATE=$(az aks show \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_NAME \
        --query provisioningState \
        --output tsv)
    
    KUBERNETES_VERSION=$(az aks show \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_NAME \
        --query kubernetesVersion \
        --output tsv)
    
    NODE_COUNT=$(az aks show \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_NAME \
        --query 'agentPoolProfiles[0].count' \
        --output tsv)
    
    echo "Cluster Details:"
    echo "  Status: $PROVISIONING_STATE"
    echo "  Kubernetes Version: $KUBERNETES_VERSION"
    echo "  Node Count: $NODE_COUNT"
    echo ""
    
    # Warning about SSH key
    echo "⚠️  WARNING: You cannot change SSH keys on an existing cluster!"
    echo ""
    echo "Your options:"
    echo ""
    echo "1. Skip infrastructure deployment (cluster already exists)"
    echo "   - Get credentials: az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --admin"
    echo "   - Fix ACR: ./fix-acr-permissions.sh $ENVIRONMENT"
    echo "   - Deploy apps: kubectl apply -f kubernetes/"
    echo ""
    echo "2. Delete and recreate (WARNING: Destroys everything)"
    echo "   - Delete: az group delete --name $RESOURCE_GROUP --yes"
    echo "   - Wait 5 minutes"
    echo "   - Deploy: ./deploy.sh $ENVIRONMENT"
    echo ""
    echo "3. Update other properties only (keep same SSH key)"
    echo "   - Make sure parameters file has the ORIGINAL SSH key"
    echo "   - Deploy: az deployment group create --resource-group $RESOURCE_GROUP --template-file main-no-rbac.bicep --parameters @parameters.dev.json"
    echo ""
    
    exit 1
else
    echo "✅ AKS cluster does not exist - safe to deploy"
    echo ""
    echo "Run: ./deploy.sh $ENVIRONMENT"
    exit 0
fi