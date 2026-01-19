#!/bin/bash

# Deploy AKS Infrastructure using Bicep
# Usage: ./deploy.sh [dev|prod]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default environment
ENVIRONMENT=${1:-dev}

# Configuration
RESOURCE_GROUP="rg-ecommerce-aks-${ENVIRONMENT}"
LOCATION="eastus"
DEPLOYMENT_NAME="aks-ecommerce-deployment-$(date +%Y%m%d-%H%M%S)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AKS Infrastructure Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "Resource Group: ${YELLOW}${RESOURCE_GROUP}${NC}"
echo -e "Location: ${YELLOW}${LOCATION}${NC}"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    echo "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
echo -e "${YELLOW}Checking Azure login status...${NC}"
az account show &> /dev/null || {
    echo -e "${RED}Not logged in to Azure. Please run 'az login'${NC}"
    exit 1
}

echo -e "${GREEN}✓ Logged in to Azure${NC}"
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo -e "Subscription: ${YELLOW}${SUBSCRIPTION_NAME}${NC}"
echo ""

# Generate SSH key if it doesn't exist
SSH_KEY_PATH="$HOME/.ssh/id_rsa_aks"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${YELLOW}Generating SSH key pair...${NC}"
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

# Update parameters file with SSH key
PARAMS_FILE="parameters.${ENVIRONMENT}.json"
echo -e "${YELLOW}Updating parameters file with SSH key...${NC}"

# Create temporary parameters file with SSH key
jq --arg ssh_key "$SSH_PUBLIC_KEY" \
   '.parameters.sshPublicKey.value = $ssh_key' \
   "$PARAMS_FILE" > "${PARAMS_FILE}.tmp"

echo -e "${GREEN}✓ Parameters updated${NC}"
echo ""

# Validate deployment
echo -e "${YELLOW}Validating Bicep deployment...${NC}"
VALIDATION_RESULT=$(az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file main.bicep \
    --parameters "@${PARAMS_FILE}.tmp" \
    --query 'properties.provisioningState' \
    --output tsv 2>&1)

if [ "$VALIDATION_RESULT" != "Succeeded" ]; then
    echo -e "${RED}✗ Validation failed${NC}"
    echo "$VALIDATION_RESULT"
    rm -f "${PARAMS_FILE}.tmp"
    exit 1
fi

echo -e "${GREEN}✓ Validation succeeded${NC}"
echo ""

# Deploy infrastructure
echo -e "${YELLOW}Starting deployment (this will take 10-15 minutes)...${NC}"
echo -e "${YELLOW}Deployment name: ${DEPLOYMENT_NAME}${NC}"
echo ""

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file main.bicep \
    --parameters "@${PARAMS_FILE}.tmp" \
    --output table

# Clean up temporary file
rm -f "${PARAMS_FILE}.tmp"

# Check deployment status
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
echo -e "${GREEN}Deployment Completed Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get outputs
echo -e "${YELLOW}Deployment Outputs:${NC}"
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

ACR_LOGIN_SERVER=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query 'properties.outputs.acrLoginServer.value' \
    --output tsv)

echo -e "AKS Cluster: ${GREEN}${AKS_NAME}${NC}"
echo -e "ACR Name: ${GREEN}${ACR_NAME}${NC}"
echo -e "ACR Login Server: ${GREEN}${ACR_LOGIN_SERVER}${NC}"
echo ""

# Get AKS credentials
echo -e "${YELLOW}Getting AKS credentials...${NC}"
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_NAME" \
    --overwrite-existing

echo -e "${GREEN}✓ Credentials saved to ~/.kube/config${NC}"
echo ""

# Verify cluster access
echo -e "${YELLOW}Verifying cluster access...${NC}"
kubectl cluster-info
echo ""

# Display nodes
echo -e "${YELLOW}Cluster nodes:${NC}"
kubectl get nodes
echo ""

# Next steps
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "1. Build and push Docker images:"
echo -e "   ${YELLOW}az acr login --name ${ACR_NAME}${NC}"
echo -e "   ${YELLOW}docker build -t ${ACR_LOGIN_SERVER}/product-service:latest services/product-service${NC}"
echo -e "   ${YELLOW}docker push ${ACR_LOGIN_SERVER}/product-service:latest${NC}"
echo ""
echo "2. Deploy applications to AKS:"
echo -e "   ${YELLOW}kubectl apply -f kubernetes/base/${NC}"
echo -e "   ${YELLOW}kubectl apply -f kubernetes/data-layer/${NC}"
echo -e "   ${YELLOW}kubectl apply -f kubernetes/services/${NC}"
echo ""
echo "3. Monitor deployment:"
echo -e "   ${YELLOW}kubectl get pods -n ecommerce -w${NC}"
echo ""
echo -e "${GREEN}Deployment complete!${NC}"