# ================================================
# Development Environment Configuration
# ================================================
# Purpose: Low-cost setup for development and testing
# Cost: ~$100-150/month

# General Configuration
location     = "eastus"
environment  = "dev"
project_name = "ecommerce-aks"

# Container Registry
# Basic tier is sufficient for dev ($5/month)
acr_sku = "Basic"

# No geo-replication needed for dev
acr_georeplications = []

# Networking Configuration
vnet_address_space        = "10.0.0.0/16"
aks_subnet_address_prefix = "10.0.1.0/24"
service_cidr              = "10.1.0.0/16"
dns_service_ip            = "10.1.0.10"

# AKS Cluster Configuration
kubernetes_version = "1.28"  # Use stable version

# Single availability zone for cost savings
availability_zones = ["1"]

# System Node Pool Configuration
# Smaller nodes for dev environment
system_node_count     = 1
system_node_min_count = 1
system_node_max_count = 2
system_node_size      = "Standard_B2s"  # Burstable, cost-effective (~$30/month)

# User Node Pool Configuration
# Can scale up during testing
user_node_count     = 1
user_node_min_count = 1
user_node_max_count = 3
user_node_size      = "Standard_B2s"  # Burstable, cost-effective (~$30/month)

# Monitoring Configuration
# Shorter retention for dev
log_retention_days = 7

# Optional Features
create_public_ip  = true   # Enable for ingress testing
create_key_vault  = false  # Not needed for dev, use Kubernetes secrets

# Development Tips:
# - Use kubectl port-forward instead of LoadBalancer services
# - Consider Azure Dev Spaces for rapid iteration
# - Use horizontal pod autoscaler sparingly
# - Stop cluster when not in use to save costs