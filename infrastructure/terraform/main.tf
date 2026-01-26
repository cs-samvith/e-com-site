terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Optional: Configure backend for state management
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "tfstatexxxxx"
  #   container_name       = "tfstate"
  #   key                  = "ecommerce.tfstate"
  # }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Local variables
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CreatedDate = timestamp()
  }
  
  resource_suffix = "${var.project_name}-${var.environment}"
  location_short  = {
    "eastus"      = "eus"
    "eastus2"     = "eus2"
    "westus"      = "wus"
    "westus2"     = "wus2"
    "centralus"   = "cus"
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.resource_suffix}"
  location = var.location
  tags     = local.common_tags
}

# Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                = replace("acr${local.resource_suffix}", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku
  admin_enabled       = true

  # Enable for production
  georeplications = var.environment == "prod" ? var.acr_georeplications : []

  tags = merge(local.common_tags, {
    Service = "Container Registry"
  })
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = merge(local.common_tags, {
    Service = "Monitoring"
  })
}

# Virtual Network for AKS
resource "azurerm_virtual_network" "aks_vnet" {
  name                = "vnet-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_address_space]

  tags = merge(local.common_tags, {
    Service = "Networking"
  })
}

# Subnet for AKS nodes
resource "azurerm_subnet" "aks_subnet" {
  name                 = "snet-aks-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = [var.aks_subnet_address_prefix]
}

# User Assigned Identity for AKS
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "id-aks-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Role assignment for AKS to pull from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

# Role assignment for AKS to manage network
resource "azurerm_role_assignment" "aks_network" {
  scope                = azurerm_virtual_network.aks_vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-${local.resource_suffix}"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.system_node_size
    type                = "VirtualMachineScaleSets"
    vnet_subnet_id      = azurerm_subnet.aks_subnet.id
    enable_auto_scaling = true
    min_count           = var.system_node_min_count
    max_count           = var.system_node_max_count
    max_pods            = 110
    os_disk_size_gb     = 128
    zones               = var.availability_zones

    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
    }

    tags = merge(local.common_tags, {
      NodePool = "system"
    })
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  azure_policy_enabled = true

  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags = merge(local.common_tags, {
    Service = "Kubernetes"
  })

  depends_on = [
    azurerm_role_assignment.aks_acr_pull,
    azurerm_role_assignment.aks_network
  ]
}

# User node pool for application workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.user_node_size
  node_count            = var.user_node_count
  enable_auto_scaling   = true
  min_count             = var.user_node_min_count
  max_count             = var.user_node_max_count
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id
  zones                 = var.availability_zones

  node_labels = {
    "nodepool-type" = "user"
    "environment"   = var.environment
    "workload-type" = "application"
  }

  node_taints = []

  tags = merge(local.common_tags, {
    NodePool = "user"
  })
}

# Public IP for Ingress (optional)
resource "azurerm_public_ip" "ingress" {
  count               = var.create_public_ip ? 1 : 0
  name                = "pip-ingress-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(local.common_tags, {
    Service = "Ingress"
  })
}

# Azure Key Vault (optional, for secrets)
resource "azurerm_key_vault" "main" {
  count                      = var.create_key_vault ? 1 : 0
  name                       = "kv-${replace(local.resource_suffix, "-", "")}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = var.environment == "prod" ? true : false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.aks_identity.principal_id

    secret_permissions = [
      "Get", "List"
    ]
  }

  tags = merge(local.common_tags, {
    Service = "Secrets"
  })
}

# Data source for current Azure client config
data "azurerm_client_config" "current" {}