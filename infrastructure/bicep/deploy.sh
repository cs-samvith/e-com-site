#!/bin/bash

# Deploy AKS Infrastructure using Bicep - Fixed Version
# Usage: ./deploy.sh [dev|staging|prod]

set -e  # Exit on any error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default environment
ENVIRONMENT=${1:-dev}

# Configuration
RESOURCE_GROUP="rg-ecommerce-aks-${ENVIRONMENT}"
LOCATION="eastus"
DEPLOYMENT_NAME="aks-deployment-$(date +%Y%m%d-%H%M%S)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AKS Infrastructure Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "Resource Group: ${YELLOW}${RESOURCE_GROUP}${NC}"
echo -e "Location: ${YELLOW}${LOCATION}${NC}"
echo ""

# Check Azure CLI
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI not installed${NC}"
    exit 1
fi

# Check login
echo -e "${YELLOW}Checking Azure login...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${RED}Not logged in. Run 'az login'${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Logged in${NC}"
SUBSCRIPTION=$(az account show --query name -o tsv)
echo -e "Subscription: ${YELLOW}${SUBSCRIPTION}${NC}"
echo ""

# Check for existing cluster
echo -e "${YELLOW}Checking for existing cluster...${NC}"
if az aks show --resource-group $RESOURCE_GROUP --name aks-ecommerce-${ENVIRONMENT} &> /dev/null; then
    echo -e "${RED}WARNING: Cluster already exists!${NC}"
    echo -e "${YELLOW}You cannot change SSH keys on existing clusters.${NC}"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        exit 0
    fi
fi

# Generate SSH key
SSH_KEY_PATH="$HOME/.ssh/id_rsa_aks"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${YELLOW}Generating SSH key...${NC}"
    ssh-keygen -t rsa -b 2048 -f "$SSH_KEY_PATH" -N "" -C "aks-ecommerce"
    echo -e "${GREEN}✓ SSH key generated${NC}"
else
    echo -e "${GREEN}✓ Using existing SSH key${NC}"
fi

SSH_PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")
echo ""

# Create resource group
echo -e "${YELLOW}Creating resource group: ${RESOURCE_GROUP}${NC}"
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none

echo -e "${GREEN}✓ Resource group created${NC}"
echo ""

# Create parameters file
echo -e "${YELLOW}Creating parameters file...${NC}"

cat > parameters.tmp.json <<EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": {
      "value": "${ENVIRONMENT}"
    },
    "sshPublicKey": {
      "value": "${SSH_PUBLIC_KEY}"
    }
  }
}
EOF

echo -e "${GREEN}✓ Parameters file created${NC}"
echo ""

# Validate
echo -e "${YELLOW}Validating template...${NC}"
if ! az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file main-no-rbac.bicep \
    --parameters @parameters.tmp.json \
    --output none 2>&1; then
    echo -e "${RED}✗ Validation failed${NC}"
    rm -f parameters.tmp.json
    exit 1
fi

echo -e "${GREEN}✓ Validation succeeded${NC}"
echo ""

# Deploy
echo -e "${YELLOW}Starting deployment (10-15 minutes)...${NC}"
echo -e "${YELLOW}Deployment name: ${DEPLOYMENT_NAME}${NC}"
echo ""

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file main-no-rbac.bicep \
    --parameters @parameters.tmp.json \
    --output table

# Clean up
rm -f parameters.tmp.json

# Check status
DEPLOYMENT_STATE=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query 'properties.provisioningState' \
    --output tsv)

if [ "$DEPLOYMENT_STATE" != "Succeeded" ]; then
    echo -e "${RED}✗ Deployment failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get outputs
AKS_NAME=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query 'properties.outputs.aksClusterName.value' \
    --output tsv)

ACR_NAME=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query 'properties.outputs.acrName.value' \
    --output tsv)

echo -e "AKS Cluster: ${GREEN}${AKS_NAME}${NC}"
echo -e "ACR Name: ${GREEN}${ACR_NAME}${NC}"
echo ""

# Get credentials
echo -e "${YELLOW}Getting AKS credentials...${NC}"
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_NAME" \
    --overwrite-existing \
    --admin

echo -e "${GREEN}✓ Credentials saved${NC}"
echo ""

# Verify
echo -e "${YELLOW}Verifying cluster...${NC}"
kubectl cluster-info
kubectl get nodes
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "1. Fix ACR permissions:"
echo -e "   ${YELLOW}./fix-acr-permissions.sh ${ENVIRONMENT}${NC}"
echo ""
echo "2. Install NGINX Ingress:"
echo -e "   ${YELLOW}kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml${NC}"
echo ""
echo "3. Build and push images (or run build pipeline)"
echo ""
echo "4. Deploy applications:"
echo -e "   ${YELLOW}kubectl apply -f kubernetes/base/${NC}"
echo -e "   ${YELLOW}kubectl apply -f kubernetes/data-layer/${NC}"
echo -e "   ${YELLOW}kubectl apply -f kubernetes/services/${NC}"
echo ""
echo -e "${GREEN}Deployment complete!${NC}"