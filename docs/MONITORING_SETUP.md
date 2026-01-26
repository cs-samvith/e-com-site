# Complete Monitoring & Alerting Setup Guide

This guide covers setting up comprehensive monitoring for your AKS infrastructure using three approaches:

1. **Azure Native** - Azure Monitor, Application Insights, Log Analytics
2. **Open Source** - Prometheus, Grafana, AlertManager
3. **Hybrid** - Best of both worlds

---

## 📊 Table of Contents

1. [Monitoring Architecture Overview](#monitoring-architecture-overview)
2. [Option A: Azure Native Monitoring](#option-a-azure-native-monitoring)
3. [Option B: Prometheus & Grafana](#option-b-prometheus--grafana)
4. [Option C: Hybrid Approach](#option-c-hybrid-approach)
5. [Setting Up Alerts](#setting-up-alerts)
6. [Creating Dashboards](#creating-dashboards)
7. [Integrating with Applications](#integrating-with-applications)
8. [Troubleshooting](#troubleshooting)

---

## Monitoring Architecture Overview

### What Gets Monitored?

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Layers                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Infrastructure Layer                                    │
│     ├── AKS Cluster (nodes, pods, deployments)             │
│     ├── Virtual Network (traffic, connections)             │
│     ├── Container Registry (image pulls, vulnerabilities)  │
│     └── Storage (disk usage, IOPS)                         │
│                                                              │
│  2. Application Layer                                       │
│     ├── Product Service (FastAPI)                          │
│     ├── User Service (FastAPI)                             │
│     ├── Frontend Service (Next.js)                         │
│     └── Databases (PostgreSQL, Redis)                      │
│                                                              │
│  3. Business Metrics                                        │
│     ├── Request rates                                       │
│     ├── Response times                                      │
│     ├── Error rates                                         │
│     └── User activity                                       │
│                                                              │
│  4. Cost & Security                                         │
│     ├── Resource costs                                      │
│     ├── Budget alerts                                       │
│     ├── Security events                                     │
│     └── Compliance violations                               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Monitoring Flow

```
Applications → Metrics → Storage → Visualization → Alerts → Notifications
     │                                    │
     │                                    ├── Dashboards
     │                                    ├── Reports
     │                                    └── Analysis
     │
     └── Logs ────────────────────────────┘
```

---

## Option A: Azure Native Monitoring

### 🎯 Best For:

- Beginners to monitoring
- Organizations already using Azure
- Managed solution preference
- Quick setup needed

### 💰 Cost: ~$50-100/month

### Components:

1. **Azure Monitor** - Central monitoring service
2. **Application Insights** - Application performance monitoring
3. **Log Analytics** - Log aggregation and querying
4. **Action Groups** - Alert notifications

### Quick Setup

#### 1. Deploy via Terraform

Already included in your `monitoring.tf`!

```bash
# Update terraform.tfvars with alert emails
cat >> infrastructure/terraform/terraform.tfvars << EOF

# Monitoring Configuration
alert_email_devops   = "devops@yourcompany.com"
alert_email_oncall   = "oncall@yourcompany.com"
monthly_budget       = 500
EOF

# Deploy monitoring
terraform apply -var-file="environments/dev.tfvars"
```

#### 2. Or Deploy via GitHub Actions

```bash
gh workflow run monitoring-deploy.yml \
  --field environment=dev \
  --field stack=azure-native
```

### What You Get:

✅ **Automatic Alerts:**

- Node CPU > 80%
- Node Memory > 80%
- Node disk usage > 90%
- Pods in failed state
- High application response time (> 3 seconds)
- Failed requests (> 10 in 15 minutes)
- Exceptions (> 5 in 15 minutes)
- Budget exceeded (80%, 100%, 120%)

✅ **Dashboards:**

- AKS cluster overview
- Application performance
- Resource utilization
- Cost analysis

### Viewing Metrics

```bash
# Azure Portal
1. Go to portal.azure.com
2. Navigate to your AKS cluster
3. Click "Monitoring" → "Insights"
4. View dashboards

# Azure CLI
az monitor metrics list \
  --resource <AKS_RESOURCE_ID> \
  --metric-names "node_cpu_usage_percentage"
```

### Key Queries (Log Analytics)

```kusto
// Failed pods in last hour
KubePodInventory
| where TimeGenerated > ago(1h)
| where ContainerStatus == "Failed"
| summarize Count=count() by Namespace, PodLabel_app

// High CPU pods
Perf
| where ObjectName == "K8SContainer"
| where CounterName == "cpuUsageNanoCores"
| summarize AvgCPU=avg(CounterValue) by Computer, InstanceName
| where AvgCPU > 800000000
| order by AvgCPU desc

// Application errors
AppRequests
| where Success == false
| summarize Count=count() by OperationName, ResultCode
| order by Count desc
```

---

## Option B: Prometheus & Grafana

### 🎯 Best For:

- Need full control and customization
- Kubernetes-native monitoring
- Open-source preference
- Complex custom metrics

### 💰 Cost: Free (just compute costs)

### Components:

1. **Prometheus** - Metrics collection and storage
2. **Grafana** - Visualization and dashboards
3. **AlertManager** - Alert routing and notifications
4. **Node Exporter** - Hardware metrics (auto-included)

### Quick Setup

#### 1. Deploy via GitHub Actions

```bash
gh workflow run monitoring-deploy.yml \
  --field environment=dev \
  --field stack=prometheus-grafana
```

#### 2. Or Deploy Manually

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-aks-dev

# Deploy monitoring stack
kubectl apply -f kubernetes/monitoring/prometheus-stack.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app=prometheus \
  -n monitoring \
  --timeout=300s

kubectl wait --for=condition=ready pod \
  -l app=grafana \
  -n monitoring \
  --timeout=300s
```

### Access the Dashboards

#### Grafana (LoadBalancer)

```bash
# Get Grafana URL
GRAFANA_IP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Grafana URL: http://$GRAFANA_IP"

# Default credentials
# Username: admin
# Password: admin123 (⚠️ CHANGE THIS!)
```

#### Prometheus (Port Forward)

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Access at: http://localhost:9090
```

#### AlertManager (Port Forward)

```bash
# Port forward AlertManager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093

# Access at: http://localhost:9093
```

### Import Grafana Dashboards

1. Login to Grafana
2. Go to **Dashboards** → **Import**
3. Enter dashboard ID and click **Load**

**Recommended Dashboards:**

- **315** - Kubernetes Cluster Monitoring
- **6417** - Kubernetes Pod Monitoring
- **1860** - Node Exporter Full
- **7249** - Kubernetes Cluster (Prometheus)
- **8588** - Container Metrics

### Custom Metrics

Add Prometheus annotations to your deployments:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
```

---

## Option C: Hybrid Approach (Recommended)

### 🎯 Best For:

- Production environments
- Need both managed and custom monitoring
- Compliance requirements
- Complete visibility

### Strategy:

**Use Azure Monitor for:**

- Infrastructure metrics (AKS, VMs, Storage)
- Cost management and budgets
- Compliance and security
- Long-term data retention (years)
- Integration with Azure services

**Use Prometheus/Grafana for:**

- Application-specific metrics
- Custom business metrics
- Real-time alerting
- Complex queries and aggregations
- Developer-friendly dashboards

### Setup Both

```bash
# Deploy both stacks
gh workflow run monitoring-deploy.yml \
  --field environment=dev \
  --field stack=both
```

### Data Flow

```
Applications
    │
    ├──→ Azure Application Insights (APM, logs)
    │
    └──→ Prometheus (Custom metrics, K8s metrics)
         │
         ├──→ Grafana (Visualization)
         │
         └──→ AlertManager (Alerts)
              │
              └──→ Azure Monitor (Long-term storage)
```

---

## Setting Up Alerts

### Azure Monitor Alerts

Already configured in Terraform! Edit thresholds in `monitoring.tf`:

```hcl
# Example: Change CPU alert threshold
resource "azurerm_monitor_metric_alert" "node_cpu" {
  # ... existing config ...

  criteria {
    threshold = 90  # Change from 80 to 90
  }
}
```

### Prometheus Alerts

Edit `kubernetes/monitoring/prometheus-stack.yaml`:

```yaml
# Add custom alert
- alert: HighDatabaseConnections
  expr: pg_stat_database_numbackends > 80
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High database connections"
    description: "Database has {{ $value }} active connections"
```

### AlertManager Notifications

#### Slack Integration

```yaml
# Edit alertmanager-config in prometheus-stack.yaml
receivers:
  - name: "critical"
    slack_configs:
      - api_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
        channel: "#alerts-critical"
        title: "🚨 Critical Alert"
        text: "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
```

#### Email Integration

```yaml
receivers:
  - name: "critical"
    email_configs:
      - to: "oncall@yourcompany.com"
        from: "alerts@yourcompany.com"
        smarthost: "smtp.gmail.com:587"
        auth_username: "your-email@gmail.com"
        auth_password: "your-app-password"
```

#### PagerDuty Integration

```yaml
receivers:
  - name: "critical"
    pagerduty_configs:
      - service_key: "YOUR_PAGERDUTY_KEY"
        description: "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
```

---

## Creating Dashboards

### Azure Monitor Dashboard

```bash
# Via Azure Portal
1. Go to portal.azure.com
2. Click "Dashboard" → "New dashboard"
3. Add tiles for:
   - AKS cluster metrics
   - Application Insights metrics
   - Cost analysis
   - Alert summary

# Via Azure CLI
az portal dashboard create \
  --name "AKS Monitoring" \
  --resource-group rg-ecommerce-aks-dev \
  --input-path dashboard.json
```

### Grafana Dashboard (JSON)

Create `kubernetes-overview.json`:

```json
{
  "dashboard": {
    "title": "Kubernetes Overview",
    "panels": [
      {
        "title": "CPU Usage",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)"
          }
        ]
      }
    ]
  }
}
```

Import via Grafana UI or API:

```bash
curl -X POST \
  http://$GRAFANA_IP/api/dashboards/db \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d @kubernetes-overview.json
```

---

## Integrating with Applications

### Python/FastAPI with Application Insights

```python
# Install package
pip install opencensus-ext-azure

# app/main.py
import logging
from opencensus.ext.azure.log_exporter import AzureLogHandler
from opencensus.ext.azure.trace_exporter import AzureExporter
from opencensus.trace.samplers import ProbabilitySampler
from opencensus.trace import config_integration
import os

# Get connection string from environment
connection_string = os.getenv('APPINSIGHTS_CONNECTION_STRING')

# Configure logging
logger = logging.getLogger(__name__)
logger.addHandler(AzureLogHandler(connection_string=connection_string))
logger.setLevel(logging.INFO)

# Configure tracing
config_integration.trace_integrations(['fastapi', 'requests'])
tracer = Tracer(
    exporter=AzureExporter(connection_string=connection_string),
    sampler=ProbabilitySampler(1.0)
)

# Use in your code
logger.info('Product service started')
logger.error('Error processing request', extra={'user_id': 123})
```

### Python/FastAPI with Prometheus

```python
# Install package
pip install prometheus-client

# app/main.py
from prometheus_client import Counter, Histogram, generate_latest
from fastapi import FastAPI, Response

app = FastAPI()

# Define metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint']
)

# Metrics endpoint
@app.get("/metrics")
def metrics():
    return Response(
        content=generate_latest(),
        media_type="text/plain"
    )

# Track metrics in middleware
@app.middleware("http")
async def track_requests(request, call_next):
    with REQUEST_DURATION.labels(
        method=request.method,
        endpoint=request.url.path
    ).time():
        response = await call_next(request)

        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.url.path,
            status=response.status_code
        ).inc()

    return response
```

### Update Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
        - name: product-service
          image: your-acr.azurecr.io/product-service:latest
          env:
            # Application Insights
            - name: APPINSIGHTS_CONNECTION_STRING
              valueFrom:
                secretKeyRef:
                  name: app-insights
                  key: connection-string
          ports:
            - containerPort: 8080
              name: http
```

---

## Troubleshooting

### Prometheus Not Scraping Targets

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit: http://localhost:9090/targets

# Check service annotations
kubectl get pods -n ecommerce -o yaml | grep prometheus

# Check service endpoints
kubectl get endpoints -n ecommerce
```

### Grafana Can't Connect to Prometheus

```bash
# Check Grafana logs
kubectl logs -n monitoring -l app=grafana

# Test Prometheus connectivity from Grafana pod
kubectl exec -n monitoring -it <grafana-pod> -- \
  wget -O- http://prometheus:9090/api/v1/status/config
```

### Azure Monitor Alerts Not Firing

```bash
# Check alert rules
az monitor metrics alert list \
  --resource-group rg-ecommerce-aks-dev

# Check metric values
az monitor metrics list \
  --resource <RESOURCE_ID> \
  --metric "node_cpu_usage_percentage" \
  --start-time 2024-01-01T00:00:00Z
```

### Application Insights Not Receiving Data

```bash
# Check connection string
kubectl get secret app-insights -n ecommerce -o yaml

# Check application logs
kubectl logs -n ecommerce <pod-name>

# Test connectivity
kubectl exec -n ecommerce <pod-name> -- \
  curl https://dc.services.visualstudio.com/v2/track
```

---

## Cost Optimization

### Azure Monitor

- **Free tier**: First 5 GB/month
- **Log retention**: Reduce to 30 days for dev
- **Sampling**: Use adaptive sampling in Application Insights

### Prometheus/Grafana

- **Retention**: Set to 15 days (already configured)
- **Scrape interval**: Increase to 30s for non-critical metrics
- **Storage**: Use persistent volumes only for production

---

## Summary

| Feature              | Azure Native   | Prometheus/Grafana | Hybrid         |
| -------------------- | -------------- | ------------------ | -------------- |
| **Setup Complexity** | Low            | Medium             | Medium         |
| **Cost**             | ~$50-100/month | Free               | ~$50-100/month |
| **Customization**    | Limited        | High               | High           |
| **Learning Curve**   | Easy           | Medium             | Medium         |
| **Best For**         | Beginners      | Advanced users     | Production     |

**Recommendation:**

- **Learning**: Start with Azure Native
- **Development**: Use Prometheus/Grafana
- **Production**: Use Hybrid approach

---

Need help? Check the troubleshooting section or create an issue! 🚀
