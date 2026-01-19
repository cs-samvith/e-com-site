# Fix ACR Permissions - Manually assign AcrPull role to AKS
# Use this if the Bicep deployment fails due to insufficient permissions

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = 'dev'
)

$ResourceGroup = "rg-ecommerce-aks-$Environment"

Write-Host "=========================================" -ForegroundColor Green
Write-Host "Fix ACR Permissions for AKS" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host ""

# Check if logged in
try {
    az account show | Out-Null
} catch {
    Write-Host "Error: Not logged in to Azure. Please run 'az login'" -ForegroundColor Red
    exit 1
}

# Get AKS cluster name
Write-Host "Getting AKS cluster name..." -ForegroundColor Yellow
$AksName = az aks list `
    --resource-group $ResourceGroup `
    --query "[0].name" `
    --output tsv

if ([string]::IsNullOrEmpty($AksName)) {
    Write-Host "Error: AKS cluster not found in $ResourceGroup" -ForegroundColor Red
    exit 1
}

Write-Host "AKS Cluster: $AksName" -ForegroundColor Green

# Get ACR name
Write-Host "Getting ACR name..." -ForegroundColor Yellow
$AcrName = az acr list `
    --resource-group $ResourceGroup `
    --query "[0].name" `
    --output tsv

if ([string]::IsNullOrEmpty($AcrName)) {
    Write-Host "Error: ACR not found in $ResourceGroup" -ForegroundColor Red
    exit 1
}

Write-Host "ACR: $AcrName" -ForegroundColor Green

# Get kubelet identity
Write-Host "Getting kubelet identity..." -ForegroundColor Yellow
$KubeletIdentity = az aks show `
    --resource-group $ResourceGroup `
    --name $AksName `
    --query identityProfile.kubeletidentity.objectId `
    --output tsv

if ([string]::IsNullOrEmpty($KubeletIdentity)) {
    Write-Host "Error: Could not get kubelet identity" -ForegroundColor Red
    exit 1
}

Write-Host "Kubelet Identity: $KubeletIdentity" -ForegroundColor Green

# Get ACR resource ID
$AcrId = az acr show `
    --name $AcrName `
    --query id `
    --output tsv

Write-Host "ACR Resource ID: $AcrId" -ForegroundColor Green

# Assign AcrPull role
Write-Host ""
Write-Host "Assigning AcrPull role to kubelet identity..." -ForegroundColor Yellow
az role assignment create `
    --assignee $KubeletIdentity `
    --role AcrPull `
    --scope $AcrId

Write-Host ""
Write-Host "✅ ACR permissions configured successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "You can now:" -ForegroundColor White
Write-Host "1. Build and push images to ACR" -ForegroundColor White
Write-Host "2. Deploy applications to AKS" -ForegroundColor White
Write-Host ""
Write-Host "Commands:" -ForegroundColor White
Write-Host "  az acr login --name $AcrName" -ForegroundColor Yellow
Write-Host "  az aks get-credentials --resource-group $ResourceGroup --name $AksName" -ForegroundColor Yellow