#!/bin/bash

# Quick patch script to fix common Bicep template issues
# Run this if you're getting subnet or output reference errors

set -e

echo "========================================="
echo "Patch Bicep Templates"
echo "========================================="
echo ""

cd "$(dirname "$0")"

echo "Backing up original templates..."
cp main.bicep main.bicep.backup 2>/dev/null || true
cp main-no-rbac.bicep main-no-rbac.bicep.backup 2>/dev/null || true
echo "✅ Backups created"
echo ""

echo "Applying fixes to main.bicep..."

# Fix 1: Replace subnet reference
sed -i.tmp 's|vnetSubnetID: vnet\.properties\.subnets\[0\]\.id|vnetSubnetID: resourceId('\''Microsoft.Network/virtualNetworks/subnets'\'', vnetName, '\''aks-subnet'\'')|g' main.bicep

# Fix 2: Add VNet dependency
if ! grep -q "dependsOn: \[" main.bicep; then
    sed -i.tmp '/identity: {/i\  dependsOn: [\n    vnet\n  ]' main.bicep
fi

# Fix 3: Fix output references
sed -i.tmp "s|output publicIPAddress string = environment != 'dev' ? publicIP\.properties\.ipAddress : 'N/A'|output publicIPAddress string = environment != 'dev' ? reference(publicIP.id, '2023-05-01').ipAddress : 'N/A'|g" main.bicep
sed -i.tmp "s|output publicIPFQDN string = environment != 'dev' ? publicIP\.properties\.dnsSettings\.fqdn : 'N/A'|output publicIPFQDN string = environment != 'dev' ? reference(publicIP.id, '2023-05-01').dnsSettings.fqdn : 'N/A'|g" main.bicep

echo "✅ main.bicep patched"
echo ""

echo "Applying fixes to main-no-rbac.bicep..."

# Apply same fixes to no-rbac template
sed -i.tmp 's|vnetSubnetID: vnet\.properties\.subnets\[0\]\.id|vnetSubnetID: resourceId('\''Microsoft.Network/virtualNetworks/subnets'\'', vnetName, '\''aks-subnet'\'')|g' main-no-rbac.bicep

if ! grep -q "dependsOn: \[" main-no-rbac.bicep; then
    sed -i.tmp '/identity: {/i\  dependsOn: [\n    vnet\n  ]' main-no-rbac.bicep
fi

sed -i.tmp "s|output publicIPAddress string = environment != 'dev' ? publicIP\.properties\.ipAddress : 'N/A'|output publicIPAddress string = environment != 'dev' ? reference(publicIP.id, '2023-05-01').ipAddress : 'N/A'|g" main-no-rbac.bicep
sed -i.tmp "s|output publicIPFQDN string = environment != 'dev' ? publicIP\.properties\.dnsSettings\.fqdn : 'N/A'|output publicIPFQDN string = environment != 'dev' ? reference(publicIP.id, '2023-05-01').dnsSettings.fqdn : 'N/A'|g" main-no-rbac.bicep

echo "✅ main-no-rbac.bicep patched"
echo ""

# Clean up temp files
rm -f *.tmp

echo "Validating templates..."
az bicep build --file main.bicep &> /dev/null && echo "✅ main.bicep is valid" || echo "⚠️  main.bicep has issues"
az bicep build --file main-no-rbac.bicep &> /dev/null && echo "✅ main-no-rbac.bicep is valid" || echo "⚠️  main-no-rbac.bicep has issues"

echo ""
echo "========================================="
echo "Patches Applied Successfully!"
echo "========================================="
echo ""
echo "Backups saved as:"
echo "  - main.bicep.backup"
echo "  - main-no-rbac.bicep.backup"
echo ""
echo "You can now deploy with:"
echo "  ./deploy.sh dev"