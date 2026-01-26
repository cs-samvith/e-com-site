# General Variables
variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
  default     = "ecommerce-aks"
}

# Container Registry Variables
variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Basic"
  
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

variable "acr_georeplications" {
  description = "Geo-replication locations for ACR (Premium only)"
  type = list(object({
    location                = string
    zone_redundancy_enabled = bool
  }))
  default = []
}

# Networking Variables
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_address_prefix" {
  description = "Address prefix for AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service"
  type        = string
  default     = "10.1.0.10"
}

# AKS Cluster Variables
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "availability_zones" {
  description = "Availability zones for AKS nodes"
  type        = list(string)
  default     = ["1", "2", "3"]
}

# System Node Pool Variables
variable "system_node_count" {
  description = "Initial number of system nodes"
  type        = number
  default     = 2
}

variable "system_node_min_count" {
  description = "Minimum number of system nodes"
  type        = number
  default     = 1
}

variable "system_node_max_count" {
  description = "Maximum number of system nodes"
  type        = number
  default     = 3
}

variable "system_node_size" {
  description = "VM size for system nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

# User Node Pool Variables
variable "user_node_count" {
  description = "Initial number of user nodes"
  type        = number
  default     = 2
}

variable "user_node_min_count" {
  description = "Minimum number of user nodes"
  type        = number
  default     = 1
}

variable "user_node_max_count" {
  description = "Maximum number of user nodes"
  type        = number
  default     = 5
}

variable "user_node_size" {
  description = "VM size for user nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

# Monitoring Variables
variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

# Optional Features
variable "create_public_ip" {
  description = "Create public IP for ingress"
  type        = bool
  default     = true
}

variable "create_key_vault" {
  description = "Create Azure Key Vault"
  type        = bool
  default     = true
}

# Monitoring & Alerting Variables
variable "alert_email_devops" {
  description = "Email address for DevOps team alerts"
  type        = string
  default     = ""
}

variable "alert_email_oncall" {
  description = "Email address for on-call engineer alerts"
  type        = string
  default     = ""
}

variable "alert_phone_numbers" {
  description = "Phone numbers for SMS alerts (format: 1234567890)"
  type        = list(string)
  default     = []
}

variable "alert_webhook_url" {
  description = "Webhook URL for Slack/Teams notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "monthly_budget" {
  description = "Monthly budget in USD for cost alerts"
  type        = number
  default     = 500
}