# ================================================
# Azure Native Monitoring Resources
# ================================================

# Application Insights for application monitoring
resource "azurerm_application_insights" "main" {
  name                = "appi-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = merge(local.common_tags, {
    Service = "Application Insights"
  })
}

# Action Group for notifications
resource "azurerm_monitor_action_group" "critical" {
  name                = "ag-critical-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "critical"

  email_receiver {
    name                    = "devops-team"
    email_address           = var.alert_email_devops
    use_common_alert_schema = true
  }

  email_receiver {
    name                    = "oncall-engineer"
    email_address           = var.alert_email_oncall
    use_common_alert_schema = true
  }

  # Optional: SMS notifications
  dynamic "sms_receiver" {
    for_each = var.alert_phone_numbers
    content {
      name         = "sms-${sms_receiver.key}"
      country_code = "1"
      phone_number = sms_receiver.value
    }
  }

  # Optional: Webhook for Slack/Teams
  dynamic "webhook_receiver" {
    for_each = var.alert_webhook_url != "" ? [1] : []
    content {
      name        = "webhook-slack"
      service_uri = var.alert_webhook_url
    }
  }

  tags = local.common_tags
}

# Action Group for warnings
resource "azurerm_monitor_action_group" "warning" {
  name                = "ag-warning-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "warning"

  email_receiver {
    name                    = "devops-team"
    email_address           = var.alert_email_devops
    use_common_alert_schema = true
  }

  tags = local.common_tags
}

# ================================================
# AKS Cluster Alerts
# ================================================

# Alert: Node CPU Usage
resource "azurerm_monitor_metric_alert" "node_cpu" {
  name                = "alert-aks-node-cpu-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_kubernetes_cluster.aks.id]
  description         = "Alert when node CPU usage exceeds threshold"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.warning.id
  }

  tags = local.common_tags
}

# Alert: Node Memory Usage
resource "azurerm_monitor_metric_alert" "node_memory" {
  name                = "alert-aks-node-memory-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_kubernetes_cluster.aks.id]
  description         = "Alert when node memory usage exceeds threshold"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_memory_working_set_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.warning.id
  }

  tags = local.common_tags
}

# Alert: Node Not Ready
resource "azurerm_monitor_metric_alert" "node_not_ready" {
  name                = "alert-aks-node-not-ready-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_kubernetes_cluster.aks.id]
  description         = "Alert when nodes are not ready"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_disk_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 90
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  tags = local.common_tags
}

# Alert: Pod Failed
resource "azurerm_monitor_metric_alert" "pod_failed" {
  name                = "alert-aks-pod-failed-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_kubernetes_cluster.aks.id]
  description         = "Alert when pods are in failed state"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "kube_pod_status_phase"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0

    dimension {
      name     = "phase"
      operator = "Include"
      values   = ["Failed"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.warning.id
  }

  tags = local.common_tags
}

# ================================================
# Application Insights Alerts
# ================================================

# Alert: High Response Time
resource "azurerm_monitor_metric_alert" "response_time" {
  name                = "alert-app-response-time-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alert when average response time is high"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 3000 # 3 seconds
  }

  action {
    action_group_id = azurerm_monitor_action_group.warning.id
  }

  tags = local.common_tags
}

# Alert: Failed Requests
resource "azurerm_monitor_metric_alert" "failed_requests" {
  name                = "alert-app-failed-requests-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alert when request failure rate is high"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  tags = local.common_tags
}

# Alert: Exception Rate
resource "azurerm_monitor_metric_alert" "exceptions" {
  name                = "alert-app-exceptions-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alert when exception rate is high"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "exceptions/count"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.warning.id
  }

  tags = local.common_tags
}

# ================================================
# Cost Management Alerts
# ================================================

# Budget Alert
resource "azurerm_consumption_budget_resource_group" "main" {
  name              = "budget-${local.resource_suffix}"
  resource_group_id = azurerm_resource_group.main.id

  amount     = var.monthly_budget
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", timestamp())
  }

  notification {
    enabled   = true
    threshold = 80
    operator  = "GreaterThan"

    contact_emails = [
      var.alert_email_devops,
    ]
  }

  notification {
    enabled   = true
    threshold = 100
    operator  = "GreaterThan"

    contact_emails = [
      var.alert_email_devops,
      var.alert_email_oncall,
    ]
  }

  notification {
    enabled   = true
    threshold = 120
    operator  = "GreaterThan"

    contact_emails = [
      var.alert_email_devops,
      var.alert_email_oncall,
    ]
  }
}

# ================================================
# Log Analytics Queries for Custom Alerts
# ================================================

# Saved query for failed deployments
resource "azurerm_log_analytics_query_pack_query" "failed_deployments" {
  query_pack_id = azurerm_log_analytics_query_pack.main.id
  body          = <<-QUERY
    KubePodInventory
    | where TimeGenerated > ago(1h)
    | where ContainerStatus == "Failed"
    | summarize Count=count() by Namespace, PodLabel_app, ContainerStatusReason
    | order by Count desc
  QUERY
  display_name  = "Failed Pods in Last Hour"
  categories    = ["container"]
}

# Query pack for storing queries
resource "azurerm_log_analytics_query_pack" "main" {
  name                = "qp-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = local.common_tags
}

# ================================================
# Diagnostic Settings
# ================================================

# Enable diagnostics for AKS
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "diag-aks-${var.environment}"
  target_resource_id         = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Enable diagnostics for ACR
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "diag-acr-${var.environment}"
  target_resource_id         = azurerm_container_registry.acr.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ================================================
# Outputs for Monitoring
# ================================================

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "application_insights_app_id" {
  description = "Application Insights application ID"
  value       = azurerm_application_insights.main.app_id
}