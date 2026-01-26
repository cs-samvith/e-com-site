# ================================================
# Production Environment Configuration
# ================================================
# Purpose: Production workloads with high availability
# Cost: ~$1,500-2,500/month

# General Configuration
location     = "eastus"
environment  = "prod"
project_name = "ecommerce-aks"

# Container Registry
# Premium tier for geo-replication, advanced features, and better SLA
acr_sku = "Premium"

# Geo-replication for disaster recovery and performance
acr_georeplications = [
  {
    location                = "westus2"
    zone_redundancy_enabled = true
  },
  {
    location                = "centralus"
    zone_redundancy_enabled = true
  }
]

# Networking Configuration
# Production CIDR range
vnet_address_space        = "10.20.0.0/16"
aks_subnet_address_prefix = "10.20.1.0/24"
service_cidr              = "10.21.0.0/16"
dns_service_ip            = "10.21.0.10"

# AKS Cluster Configuration
# Use latest stable version for security patches
kubernetes_version = "1.28"

# All three availability zones for maximum availability
availability_zones = ["1", "2", "3"]

# System Node Pool Configuration
# Production-grade nodes with redundancy
system_node_count     = 3
system_node_min_count = 3
system_node_max_count = 5
system_node_size      = "Standard_D2s_v3"  # General purpose (~$70/month per node)

# User Node Pool Configuration
# Larger nodes for production workloads
user_node_count     = 3
user_node_min_count = 3
user_node_max_count = 10
user_node_size      = "Standard_D4s_v3"  # 4 vCPUs, 16GB RAM (~$140/month per node)

# Monitoring Configuration
# Extended retention for compliance and auditing
log_retention_days = 90

# Optional Features
create_public_ip  = true   # Required for ingress
create_key_vault  = true   # Required for secrets management

# Production Best Practices:
# - Enable Azure Policy for governance
# - Configure backup and disaster recovery
# - Implement network policies for security
# - Use Pod Identity for workload authentication
# - Enable Azure Defender for security monitoring
# - Configure autoscaling based on metrics
# - Implement proper RBAC and least privilege
# - Regular security patches and updates
# - Monitor costs and set budgets/alerts
# - Document runbooks and incident response