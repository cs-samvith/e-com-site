// Main Bicep template for E-Commerce AKS Infrastructure
// Version WITHOUT automatic role assignment (for limited permissions)

@description('The location for all resources')
param location string = resourceGroup().location

@description('The name of the AKS cluster')
param aksClusterName string = 'aks-ecommerce'

@description('The name of the Azure Container Registry')
param acrName string = 'acrecommerce${uniqueString(resourceGroup().id)}'

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'dev'

@description('DNS prefix for the AKS cluster')
param dnsPrefix string = '${aksClusterName}-dns'

@description('SSH public key for AKS nodes')
param sshPublicKey string

@description('Admin username for AKS nodes')
param adminUsername string = 'azureuser'

// Variables
var nodeResourceGroup = 'rg-${aksClusterName}-nodes'
var logAnalyticsWorkspaceName = 'law-${aksClusterName}'
var applicationGatewayName = 'appgw-${aksClusterName}'
var vnetName = 'vnet-${aksClusterName}'

// Node pool configuration based on environment
var nodePoolConfig = environment == 'prod'
  ? {
      vmSize: 'Standard_D2s_v3'
      minCount: 3
      maxCount: 10
      nodeCount: 3
    }
  : {
      vmSize: 'Standard_B2ms'
      minCount: 1
      maxCount: 5
      nodeCount: 2
    }

// ============================================
// 1. Log Analytics Workspace (for monitoring)
// ============================================
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ============================================
// 2. Azure Container Registry
// ============================================
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: environment == 'prod' ? 'Standard' : 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

// ============================================
// 3. Virtual Network for AKS
// ============================================
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.0.0.0/22'
        }
      }
      {
        name: 'appgw-subnet'
        properties: {
          addressPrefix: '10.0.4.0/24'
        }
      }
    ]
  }
}

// ============================================
// 4. Public IP for Application Gateway
// ============================================
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = if (environment != 'dev') {
  name: '${applicationGatewayName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${aksClusterName}-${uniqueString(resourceGroup().id)}')
    }
  }
}

// ============================================
// 5. AKS Cluster
// ============================================
resource aks 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: aksClusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    nodeResourceGroup: nodeResourceGroup

    // Agent Pool Profile (System Node Pool)
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: nodePoolConfig.nodeCount
        vmSize: nodePoolConfig.vmSize
        osType: 'Linux'
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: vnet.properties.subnets[0].id
        enableAutoScaling: true
        minCount: nodePoolConfig.minCount
        maxCount: nodePoolConfig.maxCount
        maxPods: 30
        availabilityZones: environment == 'prod'
          ? [
              '1'
              '2'
              '3'
            ]
          : []
      }
    ]

    // Linux Profile (SSH access)
    linuxProfile: {
      adminUsername: adminUsername
      ssh: {
        publicKeys: [
          {
            keyData: sshPublicKey
          }
        ]
      }
    }

    // Network Profile
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '10.1.0.0/16'
      dnsServiceIP: '10.1.0.10'
      loadBalancerSku: 'standard'
    }

    // API Server Access Profile
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }

    // Add-ons
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalytics.id
        }
      }
      azurepolicy: {
        enabled: false
      }
      httpApplicationRouting: {
        enabled: false
      }
    }

    // RBAC
    enableRBAC: true

    // Auto-upgrade channel
    autoUpgradeProfile: {
      upgradeChannel: environment == 'prod' ? 'stable' : 'patch'
    }

    // Security Profile
    securityProfile: {
      defender: environment == 'prod'
        ? {
            logAnalyticsWorkspaceResourceId: logAnalytics.id
            securityMonitoring: {
              enabled: true
            }
          }
        : {
            securityMonitoring: {
              enabled: false
            }
          }
    }
  }
}

// ============================================
// 6. Outputs
// ============================================
output aksClusterName string = aks.name
output aksClusterFQDN string = aks.properties.fqdn
output aksClusterResourceId string = aks.id
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output acrResourceId string = acr.id
output logAnalyticsWorkspaceId string = logAnalytics.id
output vnetId string = vnet.id
output publicIPAddress string = environment != 'dev' ? publicIP.properties.ipAddress : 'N/A'
output publicIPFQDN string = environment != 'dev' ? publicIP.properties.dnsSettings.fqdn : 'N/A'
output kubeletIdentity string = aks.properties.identityProfile.kubeletidentity.objectId

// ============================================
// IMPORTANT: Manual Step Required
// ============================================
// After deployment, run this command to assign ACR pull permissions:
// 
// az role assignment create \
//   --assignee <kubelet-identity-object-id> \
//   --role AcrPull \
//   --scope <acr-resource-id>
//
// Or use the provided scripts:
// - Linux/Mac: ./fix-acr-permissions.sh dev
// - Windows: .\fix-acr-permissions.ps1 -Environment dev
