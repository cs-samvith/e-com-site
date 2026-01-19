#!/bin/bash

# Fix ACR Permissions - Manually assign AcrPull role to AKS
# Use this if the Bicep deployment fails due to insufficient permissions

set -e

# Configuration
ENVIRONMENT=${1:-dev}
RESOURCE_GROUP="rg-ecommerce-aks-${ENVIRONMENT}"

echo "========================================="
echo "Fix ACR Permissions for AKS"
echo "========================================="
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo ""

# Check if logged in
az account show &> /dev/null || {
    echo "Error: Not logged in to Azure. Please run 'az login'"
    exit 1
}

# Get AKS cluster name
echo "Getting AKS cluster name..."
AKS_NAME=$(az aks list \
    --resource-group $RESOURCE_GROUP \
    --query "[0].name" \
    --output tsv)

if [ -z "$AKS_NAME" ]; then
    echo "Error: AKS cluster not found in $RESOURCE_GROUP"
    exit 1
fi

echo "AKS Cluster: $AKS_NAME"

# Get ACR name
echo "Getting ACR name..."
ACR_NAME=$(az acr list \
    --resource-group $RESOURCE_GROUP \
    --query "[0].name" \
    --output tsv)

if [ -z "$ACR_NAME" ]; then
    echo "Error: ACR not found in $RESOURCE_GROUP"
    exit 1
fi

echo "ACR: $ACR_NAME"

# Get kubelet identity
echo "Getting kubelet identity..."
KUBELET_IDENTITY=$(az aks show \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_NAME \
    --query identityProfile.kubeletidentity.objectId \
    --output tsv)

if [ -z "$KUBELET_IDENTITY" ]; then
    echo "Error: Could not get kubelet identity"
    exit 1
fi

echo "Kubelet Identity: $KUBELET_IDENTITY"

# Get ACR resource ID
ACR_ID=$(az acr show \
    --name $ACR_NAME \
    --query id \
    --output tsv)

echo "ACR Resource ID: $ACR_ID"

# Assign AcrPull role
echo ""
echo "Assigning AcrPull role to kubelet identity..."
az role assignment create \
    --assignee $KUBELET_IDENTITY \
    --role AcrPull \
    --scope $ACR_ID

echo ""
echo "✅ ACR permissions configured successfully!"
echo ""
echo "You can now:"
echo "1. Build and push images to ACR"
echo "2. Deploy applications to AKS"
echo ""
echo "Commands:"
echo "  az acr login --name $ACR_NAME"
echo "  az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME"