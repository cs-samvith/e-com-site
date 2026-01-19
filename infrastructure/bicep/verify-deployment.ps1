# Verify AKS Deployment
# Run this after deployment to check everything is working

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = 'dev'
)

$ResourceGroup = "rg-ecommerce-aks-$Environment"

Write-Host "=========================================" -ForegroundColor Green
Write-Host "Verify AKS Deployment" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host ""

# Check Azure login
try {
    az account show | Out-Null
    Write-Host "✅ Logged in to Azure" -ForegroundColor Green
} catch {
    Write-Host "❌ Not logged in to Azure. Please run 'az login'" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Check resource group
try {
    az group show --name $ResourceGroup | Out-Null
    Write-Host "✅ Resource group exists" -ForegroundColor Green
} catch {
    Write-Host "❌ Resource group $ResourceGroup not found" -ForegroundColor Red
    exit 1
}

# Get AKS cluster
$AksName = az aks list `
    --resource-group $ResourceGroup `
    --query "[0].name" `
    --output tsv

if ([string]::IsNullOrEmpty($AksName)) {
    Write-Host "❌ AKS cluster not found" -ForegroundColor Red
    exit 1
}
Write-Host "✅ AKS cluster found: $AksName" -ForegroundColor Green

# Check AKS status
$ProvisioningState = az aks show `
    --resource-group $ResourceGroup `
    --name $AksName `
    --query provisioningState `
    --output tsv

if ($ProvisioningState -ne "Succeeded") {
    Write-Host "❌ AKS cluster not ready. Status: $ProvisioningState" -ForegroundColor Red
    exit 1
}
Write-Host "✅ AKS cluster status: $ProvisioningState" -ForegroundColor Green

# Get ACR
$AcrName = az acr list `
    --resource-group $ResourceGroup `
    --query "[0].name" `
    --output tsv

if ([string]::IsNullOrEmpty($AcrName)) {
    Write-Host "❌ ACR not found" -ForegroundColor Red
    exit 1
}
Write-Host "✅ ACR found: $AcrName" -ForegroundColor Green

# Get AKS credentials
Write-Host ""
Write-Host "Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials `
    --resource-group $ResourceGroup `
    --name $AksName `
    --overwrite-existing `
    --admin 2>$null | Out-Null

Write-Host "✅ AKS credentials configured" -ForegroundColor Green

# Test kubectl connection
Write-Host ""
Write-Host "Testing kubectl connection..." -ForegroundColor Yellow
try {
    kubectl cluster-info 2>$null | Out-Null
    Write-Host "✅ kubectl connected to cluster" -ForegroundColor Green
} catch {
    Write-Host "❌ Cannot connect to cluster with kubectl" -ForegroundColor Red
    Write-Host "Try running: az aks get-credentials --resource-group $ResourceGroup --name $AksName --overwrite-existing --admin" -ForegroundColor Yellow
    exit 1
}

# Check nodes
Write-Host ""
Write-Host "Checking nodes..." -ForegroundColor Yellow
$Nodes = kubectl get nodes --no-headers 2>$null
$NodeCount = ($Nodes | Measure-Object).Count
$ReadyCount = ($Nodes | Select-String "Ready" | Measure-Object).Count

if ($NodeCount -eq 0) {
    Write-Host "❌ No nodes found" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Nodes: $NodeCount total, $ReadyCount ready" -ForegroundColor Green
kubectl get nodes

# Check ACR integration
Write-Host ""
Write-Host "Checking ACR integration..." -ForegroundColor Yellow
$KubeletIdentity = az aks show `
    --resource-group $ResourceGroup `
    --name $AksName `
    --query identityProfile.kubeletidentity.objectId `
    --output tsv

$AcrId = az acr show `
    --name $AcrName `
    --query id `
    --output tsv

$RoleAssigned = az role assignment list `
    --assignee $KubeletIdentity `
    --scope $AcrId `
    --query "[?roleDefinitionName=='AcrPull'].roleDefinitionName" `
    --output tsv

if ([string]::IsNullOrEmpty($RoleAssigned)) {
    Write-Host "⚠️  ACR pull role not assigned" -ForegroundColor Yellow
    Write-Host "Run: .\fix-acr-permissions.ps1 -Environment $Environment" -ForegroundColor Yellow
} else {
    Write-Host "✅ ACR pull role assigned" -ForegroundColor Green
}

# Test ACR login
Write-Host ""
Write-Host "Testing ACR login..." -ForegroundColor Yellow
try {
    az acr login --name $AcrName 2>$null | Out-Null
    Write-Host "✅ ACR login successful" -ForegroundColor Green
} catch {
    Write-Host "❌ ACR login failed" -ForegroundColor Red
}

# Check Log Analytics
Write-Host ""
Write-Host "Checking Log Analytics..." -ForegroundColor Yellow
$LawName = az monitor log-analytics workspace list `
    --resource-group $ResourceGroup `
    --query "[0].name" `
    --output tsv

if ([string]::IsNullOrEmpty($LawName)) {
    Write-Host "⚠️  Log Analytics workspace not found" -ForegroundColor Yellow
} else {
    Write-Host "✅ Log Analytics workspace: $LawName" -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Deployment Verification Summary" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Resource Group: $ResourceGroup" -ForegroundColor Green
Write-Host "✅ AKS Cluster: $AksName ($ProvisioningState)" -ForegroundColor Green
Write-Host "✅ Nodes: $NodeCount ($ReadyCount ready)" -ForegroundColor Green
Write-Host "✅ ACR: $AcrName" -ForegroundColor Green

if (-not [string]::IsNullOrEmpty($RoleAssigned)) {
    Write-Host "✅ ACR Integration: Configured" -ForegroundColor Green
} else {
    Write-Host "⚠️  ACR Integration: Needs configuration" -ForegroundColor Yellow
}

if (-not [string]::IsNullOrEmpty($LawName)) {
    Write-Host "✅ Log Analytics: $LawName" -ForegroundColor Green
}
Write-Host ""

# Next steps
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Next Steps" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

if ([string]::IsNullOrEmpty($RoleAssigned)) {
    Write-Host "1. Fix ACR permissions:" -ForegroundColor White
    Write-Host "   .\fix-acr-permissions.ps1 -Environment $Environment" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "2. Build and push images:" -ForegroundColor White
Write-Host "   az acr login --name $AcrName" -ForegroundColor Yellow
Write-Host "   docker build -t $AcrName.azurecr.io/product-service:latest services/product-service" -ForegroundColor Yellow
Write-Host "   docker push $AcrName.azurecr.io/product-service:latest" -ForegroundColor Yellow
Write-Host ""

Write-Host "3. Deploy applications:" -ForegroundColor White
Write-Host "   kubectl apply -f kubernetes/base/" -ForegroundColor Yellow
Write-Host "   kubectl apply -f kubernetes/data-layer/" -ForegroundColor Yellow
Write-Host "   kubectl apply -f kubernetes/services/" -ForegroundColor Yellow
Write-Host ""

Write-Host "4. Check deployment:" -ForegroundColor White
Write-Host "   kubectl get pods -n ecommerce" -ForegroundColor Yellow
Write-Host ""

Write-Host "✅ Verification complete!" -ForegroundColor Green