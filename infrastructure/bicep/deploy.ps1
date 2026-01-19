# Deploy AKS Infrastructure using Bicep
# Usage: .\deploy.ps1 -Environment dev

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment = 'dev'
)

# Configuration
$ResourceGroup = "rg-ecommerce-aks-$Environment"
$Location = "eastus"
$DeploymentName = "aks-ecommerce-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "========================================" -ForegroundColor Green
Write-Host "AKS Infrastructure Deployment" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host ""

# Check if Azure CLI is installed
try {
    az version | Out-Null
    Write-Host "✓ Azure CLI found" -ForegroundColor Green
} catch {
    Write-Host "✗ Azure CLI is not installed" -ForegroundColor Red
    Write-Host "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
    exit 1
}

# Check if logged in to Azure
Write-Host "Checking Azure login status..." -ForegroundColor Yellow
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    Write-Host "✓ Logged in to Azure" -ForegroundColor Green
    Write-Host "Subscription: $($account.name)" -ForegroundColor Yellow
} catch {
    Write-Host "✗ Not logged in to Azure. Please run 'az login'" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Generate SSH key if it doesn't exist
$SSHKeyPath = "$env:USERPROFILE\.ssh\id_rsa_aks"
if (-not (Test-Path $SSHKeyPath)) {
    Write-Host "Generating SSH key pair..." -ForegroundColor Yellow
    ssh-keygen -t rsa -b 2048 -f $SSHKeyPath -N '""' -C "aks-ecommerce"
    Write-Host "✓ SSH key generated" -ForegroundColor Green
} else {
    Write-Host "✓ Using existing SSH key" -ForegroundColor Green
}

$SSHPublicKey = Get-Content "$SSHKeyPath.pub" -Raw
Write-Host ""

# Create resource group
Write-Host "Creating resource group: $ResourceGroup" -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location --output none
Write-Host "✓ Resource group created" -ForegroundColor Green
Write-Host ""

# Update parameters file with SSH key
$ParamsFile = "parameters.$Environment.json"
Write-Host "Updating parameters file with SSH key..." -ForegroundColor Yellow

$params = Get-Content $ParamsFile | ConvertFrom-Json
$params.parameters.sshPublicKey.value = $SSHPublicKey.Trim()
$TempParamsFile = "$ParamsFile.tmp"
$params | ConvertTo-Json -Depth 10 | Set-Content $TempParamsFile

Write-Host "✓ Parameters updated" -ForegroundColor Green
Write-Host ""

# Validate deployment
Write-Host "Validating Bicep deployment..." -ForegroundColor Yellow
$validationResult = az deployment group validate `
    --resource-group $ResourceGroup `
    --template-file main.bicep `
    --parameters "@$TempParamsFile" `
    --query 'properties.provisioningState' `
    --output tsv 2>&1

if ($validationResult -ne "Succeeded") {
    Write-Host "✗ Validation failed" -ForegroundColor Red
    Write-Host $validationResult
    Remove-Item $TempParamsFile -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "✓ Validation succeeded" -ForegroundColor Green
Write-Host ""

# Deploy infrastructure
Write-Host "Starting deployment (this will take 10-15 minutes)..." -ForegroundColor Yellow
Write-Host "Deployment name: $DeploymentName" -ForegroundColor Yellow
Write-Host ""

az deployment group create `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --template-file main.bicep `
    --parameters "@$TempParamsFile" `
    --output table

# Clean up temporary file
Remove-Item $TempParamsFile -ErrorAction SilentlyContinue

# Check deployment status
$deploymentState = az deployment group show `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --query 'properties.provisioningState' `
    --output tsv

if ($deploymentState -ne "Succeeded") {
    Write-Host "✗ Deployment failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment Completed Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Get outputs
Write-Host "Deployment Outputs:" -ForegroundColor Yellow
$aksName = az deployment group show `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --query 'properties.outputs.aksClusterName.value' `
    --output tsv

$acrName = az deployment group show `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --query 'properties.outputs.acrName.value' `
    --output tsv

$acrLoginServer = az deployment group show `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --query 'properties.outputs.acrLoginServer.value' `
    --output tsv

Write-Host "AKS Cluster: $aksName" -ForegroundColor Green
Write-Host "ACR Name: $acrName" -ForegroundColor Green
Write-Host "ACR Login Server: $acrLoginServer" -ForegroundColor Green
Write-Host ""

# Get AKS credentials
Write-Host "Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials `
    --resource-group $ResourceGroup `
    --name $aksName `
    --overwrite-existing

Write-Host "✓ Credentials saved to ~/.kube/config" -ForegroundColor Green
Write-Host ""

# Verify cluster access
Write-Host "Verifying cluster access..." -ForegroundColor Yellow
kubectl cluster-info
Write-Host ""

# Display nodes
Write-Host "Cluster nodes:" -ForegroundColor Yellow
kubectl get nodes
Write-Host ""

# Next steps
Write-Host "========================================" -ForegroundColor Green
Write-Host "Next Steps:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "1. Build and push Docker images:" -ForegroundColor White
Write-Host "   az acr login --name $acrName" -ForegroundColor Yellow
Write-Host "   docker build -t $acrLoginServer/product-service:latest services/product-service" -ForegroundColor Yellow
Write-Host "   docker push $acrLoginServer/product-service:latest" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. Deploy applications to AKS:" -ForegroundColor White
Write-Host "   kubectl apply -f kubernetes/base/" -ForegroundColor Yellow
Write-Host "   kubectl apply -f kubernetes/data-layer/" -ForegroundColor Yellow
Write-Host "   kubectl apply -f kubernetes/services/" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. Monitor deployment:" -ForegroundColor White
Write-Host "   kubectl get pods -n ecommerce -w" -ForegroundColor Yellow
Write-Host ""
Write-Host "Deployment complete!" -ForegroundColor Green