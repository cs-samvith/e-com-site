# ================================================
# Staging Environment Configuration
# ================================================
# Purpose: Pre-production testing with production-like setup
# Cost: ~$400-600/month

# General Configuration
location     = "eastus"
environment  = "staging"
project_name = "ecommerce-aks"

# Container Registry
# Standard tier for better performance and some features
acr_sku = "Standard"

# No geo-replication for staging
acr_georeplications = []

# Networking Configuration
# Different CIDR to avoid conflicts with dev/prod
vnet_address_space        = "10.10.0.0/16"
aks_subnet_address_prefix = "10.10.1.0/24"
service_cidr              = "10.11.0.0/16"
dns_service_ip            = "10.11.0.10"

# AKS Cluster Configuration
kubernetes_version = "1.28"  # Match production version

# Two availability zones for better reliability
availability_zones = ["1", "2"]

# System Node Pool Configuration
# Production-grade nodes
system_node_count     = 2
system_node_min_count = 2
system_node_max_count = 3
system_node_size      = "Standard_D2s_v3"  # General purpose (~$70/month per node)

# User Node Pool Configuration
# Similar to production capacity
user_node_count     = 2
user_node_min_count = 2
user_node_max_count = 4
user_node_size      = "Standard_D2s_v3"  # General purpose (~$70/month per node)

# Monitoring Configuration
# Moderate retention for staging
log_retention_days = 30

# Optional Features
create_public_ip  = true   # Enable for integration testing
create_key_vault  = true   # Test Key Vault integration

# Staging Best Practices:
# - Mirror production configuration as closely as possible
# - Use for load testing and performance benchmarking
# - Test CI/CD pipelines before deploying to production
# - Use production-like data volumes (anonymized)
# - Test disaster recovery procedures
# - Validate monitoring and alerting