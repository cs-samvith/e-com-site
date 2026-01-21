# E-Commerce Helm Chart

Helm chart for deploying the complete e-commerce microservices application to Kubernetes.

---

## 📦 **What This Chart Deploys**

- **3 Microservices:**
  - Product Service (Port 8081)
  - User Service (Port 8080)
  - Frontend Service (Port 3000)

- **Data Layer:**
  - PostgreSQL (via Bitnami chart)
  - Redis (via Bitnami chart)
  - RabbitMQ (via Bitnami chart)

- **Networking:**
  - Kubernetes Services
  - Ingress (NGINX)

- **Autoscaling:**
  - Horizontal Pod Autoscaler (HPA) for each service

---

## 🚀 **Quick Start**

### **Prerequisites**

- Helm 3.x installed
- kubectl configured to your AKS cluster
- NGINX Ingress Controller installed

---

### **Install**

```bash
# Add Bitnami repo (for dependencies)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install for development
helm install ecommerce ./helm/ecommerce \
  --namespace ecommerce \
  --create-namespace \
  --values helm/ecommerce/values-dev.yaml

# Wait for deployment
kubectl get pods -n ecommerce -w
```

---

### **Upgrade**

```bash
# Upgrade with new image tags
helm upgrade ecommerce ./helm/ecommerce \
  --namespace ecommerce \
  --values helm/ecommerce/values-dev.yaml \
  --set productService.image.tag=v1.1.0 \
  --set userService.image.tag=v1.1.0
```

---

### **Uninstall**

```bash
helm uninstall ecommerce -n ecommerce

# Delete namespace (optional)
kubectl delete namespace ecommerce
```

---

## ⚙️ **Configuration**

### **Values Files**

- `values.yaml` - Default values
- `values-dev.yaml` - Development overrides
- `values-staging.yaml` - Staging overrides (create this)
- `values-prod.yaml` - Production overrides (create this)

---

### **Key Configuration Options**

```yaml
# Image settings
global:
  imageRegistry: acrecommercedev.azurecr.io
  imagePullPolicy: Always

# Service-specific
productService:
  enabled: true
  replicaCount: 2
  image:
    repository: product-service
    tag: latest

# Database
postgresql:
  enabled: true
  auth:
    password: "your-password"

# Ingress
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: ecommerce.local
```

---

## 🔧 **Common Operations**

### **Check Release Status**

```bash
helm status ecommerce -n ecommerce
```

---

### **View Current Values**

```bash
helm get values ecommerce -n ecommerce
```

---

### **See What Will Change**

```bash
# Dry-run upgrade
helm upgrade ecommerce ./helm/ecommerce \
  --namespace ecommerce \
  --values helm/ecommerce/values-dev.yaml \
  --dry-run \
  --debug
```

---

### **Rollback**

```bash
# List revisions
helm history ecommerce -n ecommerce

# Rollback to previous version
helm rollback ecommerce -n ecommerce

# Rollback to specific revision
helm rollback ecommerce 2 -n ecommerce
```

---

## 🎯 **Environment-Specific Deployments**

### **Development**

```bash
helm install ecommerce ./helm/ecommerce \
  -n ecommerce \
  --create-namespace \
  -f helm/ecommerce/values-dev.yaml
```

**Features:**

- 1 replica per service
- Smaller resource limits
- No persistence for Redis
- Simple passwords

---

### **Staging** (create values-staging.yaml)

```bash
helm install ecommerce ./helm/ecommerce \
  -n ecommerce \
  --create-namespace \
  -f helm/ecommerce/values-staging.yaml \
  --set secrets.postgres.password=$STAGING_DB_PASSWORD
```

**Features:**

- 2 replicas per service
- Medium resource limits
- Persistence enabled
- Secure passwords from variables

---

### **Production** (create values-prod.yaml)

```bash
helm install ecommerce ./helm/ecommerce \
  -n ecommerce-prod \
  --create-namespace \
  -f helm/ecommerce/values-prod.yaml \
  --set secrets.postgres.password=$PROD_DB_PASSWORD \
  --set secrets.jwt.secret=$JWT_SECRET
```

**Features:**

- 3+ replicas per service
- High resource limits
- Full persistence
- Secrets from Azure Key Vault

---

## 🔐 **Security Best Practices**

### **Don't Store Secrets in values.yaml!**

**For production, use:**

**Option 1: Pass as command-line arguments**

```bash
helm install ecommerce ./helm/ecommerce \
  --set secrets.postgres.password=$DB_PASSWORD \
  --set secrets.jwt.secret=$JWT_SECRET
```

**Option 2: Use Azure Key Vault**

```bash
# Get secrets from Key Vault
DB_PASSWORD=$(az keyvault secret show --vault-name kv-ecommerce --name postgres-password --query value -o tsv)

helm install ecommerce ./helm/ecommerce \
  --set secrets.postgres.password=$DB_PASSWORD
```

**Option 3: Use Helm Secrets Plugin**

```bash
helm plugin install https://github.com/jkroepke/helm-secrets

# Encrypt values file
helm secrets encrypt helm/ecommerce/values-prod.yaml

# Deploy with encrypted values
helm secrets install ecommerce ./helm/ecommerce -f helm/ecommerce/values-prod.yaml.enc
```

---

## 📊 **Monitoring Deployment**

### **Watch Pods Start**

```bash
kubectl get pods -n ecommerce -w
```

---

### **Check Logs**

```bash
# All services
kubectl logs -l app.kubernetes.io/instance=ecommerce -n ecommerce

# Specific service
kubectl logs -l app=product-service -n ecommerce -f
```

---

### **Test Application**

```bash
# Get ingress IP
INGRESS_IP=$(kubectl get ingress -n ecommerce -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# Test endpoints
curl http://$INGRESS_IP/api/products
curl http://$INGRESS_IP/api/users
curl http://$INGRESS_IP/
```

---

## 🐛 **Troubleshooting**

### **Helm Install Fails**

```bash
# Check what Helm is trying to create
helm template ecommerce ./helm/ecommerce --debug

# Check Helm release status
helm list -n ecommerce --all

# Get failure details
helm status ecommerce -n ecommerce
```

---

### **Pods Not Starting**

```bash
# Check pod events
kubectl describe pod <POD_NAME> -n ecommerce

# Check logs
kubectl logs <POD_NAME> -n ecommerce

# Check if images exist
kubectl describe pod <POD_NAME> -n ecommerce | grep "image"
```

---

### **Dependencies Not Installing**

```bash
# Update dependencies manually
helm dependency update ./helm/ecommerce

# Check dependencies
helm dependency list ./helm/ecommerce
```

---

## 🔄 **CI/CD Integration**

### **Azure DevOps Pipeline**

Use the provided `azure-pipelines/helm-deploy-pipeline.yml`:

```bash
# Trigger manually or on helm/* changes
# Select environment: dev/staging/prod
# Select action: install/upgrade/uninstall
```

---

### **GitHub Actions** (create this)

```yaml
name: Helm Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: choice
        options: [dev, staging, prod]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/setup-helm@v3
        with:
          version: "3.13.0"

      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Deploy with Helm
        run: |
          az aks get-credentials --resource-group rg-ecommerce-aks-dev --name aks-ecommerce-dev
          helm upgrade --install ecommerce ./helm/ecommerce -n ecommerce --create-namespace -f helm/ecommerce/values-${{ inputs.environment }}.yaml
```

---

## 📁 **Chart Structure**

```
helm/ecommerce/
├── Chart.yaml                 # Chart metadata
├── values.yaml                # Default values
├── values-dev.yaml            # Development overrides
├── values-staging.yaml        # Staging overrides
├── values-prod.yaml           # Production overrides
├── README.md                  # This file
├── templates/
│   ├── _helpers.tpl           # Helper functions
│   ├── product-service-deployment.yaml
│   ├── product-service-service.yaml
│   ├── product-service-hpa.yaml
│   ├── user-service-deployment.yaml
│   ├── user-service-service.yaml
│   ├── user-service-hpa.yaml
│   ├── frontend-service-deployment.yaml
│   ├── frontend-service-service.yaml
│   ├── frontend-service-hpa.yaml
│   ├── secrets.yaml
│   └── ingress.yaml
└── charts/                    # Dependency charts (auto-downloaded)
    ├── postgresql/
    ├── redis/
    └── rabbitmq/
```

---

## ✅ **Benefits of Using Helm**

**vs Raw Kubernetes Manifests:**

1. **Templating** - One chart, multiple environments
2. **Dependency Management** - PostgreSQL, Redis, RabbitMQ included
3. **Versioning** - Easy rollbacks
4. **Values Override** - Environment-specific configs
5. **Package Management** - Single command to deploy everything
6. **Lifecycle Management** - Install, upgrade, rollback, uninstall

---

## 🎓 **Learning Resources**

- **Helm Docs:** https://helm.sh/docs/
- **Best Practices:** https://helm.sh/docs/chart_best_practices/
- **Chart Development:** https://helm.sh/docs/chart_template_guide/

---

## 📋 **Checklist**

Before deploying:

- [ ] Helm 3.x installed
- [ ] kubectl connected to cluster
- [ ] NGINX Ingress Controller installed
- [ ] Images built and pushed to ACR
- [ ] Values file updated for environment
- [ ] Secrets configured (not hardcoded!)

---

**Deploy your entire application with one command using Helm!** 🚀
