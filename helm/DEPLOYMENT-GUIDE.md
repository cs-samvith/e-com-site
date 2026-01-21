# Helm Deployment Guide

Complete guide to deploying your e-commerce application using Helm.

---

## 📁 **Folder Structure**

```
helm/
├── ecommerce/
│   ├── Chart.yaml                           # Chart metadata
│   ├── values.yaml                          # Default values
│   ├── values-dev.yaml                      # Dev environment
│   ├── values-prod.yaml                     # Prod environment
│   ├── README.md                            # Chart documentation
│   ├── templates/
│   │   ├── _helpers.tpl                     # Helper functions
│   │   ├── secrets.yaml                     # Secrets
│   │   ├── product-service-deployment.yaml
│   │   ├── product-service-service.yaml
│   │   ├── user-service-deployment.yaml
│   │   ├── user-service-service.yaml
│   │   ├── frontend-service-deployment.yaml
│   │   ├── frontend-service-service.yaml
│   │   ├── services.yaml                    # All services
│   │   ├── hpa.yaml                         # All HPAs
│   │   └── ingress.yaml                     # Ingress
│   └── charts/                              # Dependencies (auto-created)
│       ├── postgresql-12.x.x.tgz
│       ├── redis-17.x.x.tgz
│       └── rabbitmq-12.x.x.tgz
└── HELM_DEPLOYMENT_GUIDE.md                 # This file
```

---

## 🚀 **Installation Steps**

### **Step 1: Install Helm**

```bash
# Download and install Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version

# Should show: version.BuildInfo{Version:"v3.13.x"...}
```

---

### **Step 2: Add Required Helm Repositories**

```bash
# Add Bitnami repo for PostgreSQL, Redis, RabbitMQ
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repos
helm repo update

# Verify
helm search repo bitnami/postgresql
helm search repo bitnami/redis
helm search repo bitnami/rabbitmq
```

---

### **Step 3: Download Chart Dependencies**

```bash
cd helm/ecommerce

# Download PostgreSQL, Redis, RabbitMQ charts
helm dependency update

# Verify dependencies downloaded
ls charts/

# Should show:
# postgresql-12.x.x.tgz
# redis-17.x.x.tgz
# rabbitmq-12.x.x.tgz
```

---

### **Step 4: Validate Chart**

```bash
# Lint the chart
helm lint .

# Should show: ==> Linting . 1 chart(s) linted, 0 chart(s) failed

# Dry-run for development
helm template ecommerce . \
  --values values-dev.yaml \
  --debug \
  --dry-run

# Check the rendered YAML
```

---

### **Step 5: Deploy to Development**

```bash
# Create namespace
kubectl create namespace ecommerce

# Install chart
helm install ecommerce . \
  --namespace ecommerce \
  --values values-dev.yaml \
  --wait \
  --timeout 10m

# Watch deployment
kubectl get pods -n ecommerce -w
```

---

## 📊 **Deployment Commands**

### **Development**

```bash
helm install ecommerce ./helm/ecommerce \
  -n ecommerce \
  --create-namespace \
  -f helm/ecommerce/values-dev.yaml
```

---

### **Staging**

```bash
helm install ecommerce ./helm/ecommerce \
  -n ecommerce \
  --create-namespace \
  -f helm/ecommerce/values-staging.yaml \
  --set secrets.postgres.password=$STAGING_DB_PASSWORD \
  --set secrets.jwt.secret=$STAGING_JWT_SECRET
```

---

### **Production**

```bash
# NEVER hardcode production secrets!
# Get from Azure Key Vault or pass securely

POSTGRES_PASSWORD=$(az keyvault secret show --vault-name kv-ecommerce --name postgres-password --query value -o tsv)
JWT_SECRET=$(az keyvault secret show --vault-name kv-ecommerce --name jwt-secret --query value -o tsv)
RABBITMQ_PASSWORD=$(az keyvault secret show --vault-name kv-ecommerce --name rabbitmq-password --query value -o tsv)

helm install ecommerce ./helm/ecommerce \
  -n ecommerce-prod \
  --create-namespace \
  -f helm/ecommerce/values-prod.yaml \
  --set secrets.postgres.password=$POSTGRES_PASSWORD \
  --set secrets.jwt.secret=$JWT_SECRET \
  --set secrets.rabbitmq.password=$RABBITMQ_PASSWORD \
  --set productService.image.tag=v1.0.0 \
  --set userService.image.tag=v1.0.0 \
  --set frontendService.image.tag=v1.0.0
```

---

## 🔄 **Upgrade Operations**

### **Upgrade with New Image**

```bash
# Upgrade to new version
helm upgrade ecommerce ./helm/ecommerce \
  -n ecommerce \
  -f helm/ecommerce/values-dev.yaml \
  --set productService.image.tag=v1.1.0 \
  --wait

# Check rollout status
kubectl rollout status deployment/ecommerce-product-service -n ecommerce
```

---

### **Upgrade Configuration Only**

```bash
# Change replica count
helm upgrade ecommerce ./helm/ecommerce \
  -n ecommerce \
  -f helm/ecommerce/values-dev.yaml \
  --set productService.replicaCount=3
```

---

### **Upgrade with New Values File**

```bash
# Edit values-dev.yaml, then:
helm upgrade ecommerce ./helm/ecommerce \
  -n ecommerce \
  -f helm/ecommerce/values-dev.yaml
```

---

## ⏮️ **Rollback**

### **View History**

```bash
# List all revisions
helm history ecommerce -n ecommerce

# Output:
# REVISION  UPDATED                   STATUS      DESCRIPTION
# 1         Mon Jan 20 10:00:00 2026  superseded  Install complete
# 2         Mon Jan 20 11:00:00 2026  deployed    Upgrade complete
```

---

### **Rollback to Previous**

```bash
# Rollback to previous revision
helm rollback ecommerce -n ecommerce

# Or specific revision
helm rollback ecommerce 1 -n ecommerce
```

---

## 🔍 **Debugging**

### **Check Release Status**

```bash
helm status ecommerce -n ecommerce
```

---

### **Get Rendered Values**

```bash
# See all computed values
helm get values ecommerce -n ecommerce

# See all values (including defaults)
helm get values ecommerce -n ecommerce --all
```

---

### **Get Rendered Manifests**

```bash
# See actual Kubernetes YAML deployed
helm get manifest ecommerce -n ecommerce
```

---

### **Test Before Deploying**

```bash
# Render templates locally
helm template ecommerce ./helm/ecommerce \
  -f helm/ecommerce/values-dev.yaml \
  --debug

# Dry-run install
helm install ecommerce ./helm/ecommerce \
  -n ecommerce \
  -f helm/ecommerce/values-dev.yaml \
  --dry-run \
  --debug
```

---

## 🧹 **Cleanup**

### **Uninstall Release**

```bash
# Uninstall (keeps namespace and PVCs)
helm uninstall ecommerce -n ecommerce

# Delete namespace
kubectl delete namespace ecommerce

# Delete PVCs manually if needed
kubectl delete pvc --all -n ecommerce
```

---

## 🎯 **Using the Azure DevOps Pipeline**

### **Setup**

1. **Import the pipeline:**
   - Go to Azure DevOps → Pipelines
   - New pipeline → Existing YAML
   - Select: `azure-pipelines/helm-deploy-pipeline.yml`

2. **Run the pipeline:**
   - Click "Run pipeline"
   - Select environment (dev/staging/prod)
   - Select action (install/upgrade/uninstall)
   - Click "Run"

---

### **What the Pipeline Does**

**Stage 1: Validate**

- Lints Helm chart
- Validates templates
- Checks syntax

**Stage 2: Deploy**

- Gets AKS credentials
- Adds Bitnami repo
- Determines if install or upgrade
- Creates namespace
- Deploys with Helm
- Shows status
- Gets ingress IP

**Stage 3: Uninstall** (if action=uninstall)

- Removes Helm release
- Preserves PVCs

---

## 📝 **Customizing Values**

### **Override Single Value**

```bash
helm install ecommerce ./helm/ecommerce \
  --set productService.replicaCount=5
```

---

### **Override Multiple Values**

```bash
helm install ecommerce ./helm/ecommerce \
  --set productService.replicaCount=5 \
  --set userService.replicaCount=3 \
  --set frontendService.image.tag=v2.0.0
```

---

### **Use Custom Values File**

```bash
# Create custom-values.yaml
cat > custom-values.yaml <<EOF
productService:
  replicaCount: 5
  image:
    tag: latest
EOF

# Deploy with it
helm install ecommerce ./helm/ecommerce \
  -f helm/ecommerce/values-dev.yaml \
  -f custom-values.yaml
```

**Values merge priority:**

1. values.yaml (lowest)
2. values-dev.yaml
3. custom-values.yaml
4. --set flags (highest)

---

## 🔐 **Managing Secrets**

### **Development (Not Secure)**

```yaml
# In values-dev.yaml (OK for dev)
secrets:
  postgres:
    password: postgres123
```

---

### **Production (Secure)**

**Option 1: Pass via CLI**

```bash
helm install ecommerce ./helm/ecommerce \
  --set secrets.postgres.password=$DB_PASSWORD
```

**Option 2: Create Secrets Separately**

```bash
# Create secrets manually
kubectl create secret generic ecommerce-secrets \
  --from-literal=postgres-password=$DB_PASSWORD \
  --from-literal=jwt-secret=$JWT_SECRET \
  -n ecommerce

# Disable Helm secret creation
helm install ecommerce ./helm/ecommerce \
  --set secrets.create=false
```

**Option 3: Azure Key Vault CSI Driver**

```bash
# Use external-secrets or CSI driver
# Chart will reference existing secrets
```

---

## 📈 **Monitoring Deployment**

### **Watch All Resources**

```bash
# Watch everything
watch kubectl get all -n ecommerce

# Or specific resources
kubectl get pods,svc,ingress -n ecommerce -w
```

---

### **Check Helm Release**

```bash
# Current status
helm list -n ecommerce

# Detailed status
helm status ecommerce -n ecommerce

# Show notes
helm get notes ecommerce -n ecommerce
```

---

## 🧪 **Testing After Deployment**

```bash
# Get ingress IP
INGRESS_IP=$(kubectl get ingress -n ecommerce -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# Test endpoints
curl http://$INGRESS_IP/api/products
curl http://$INGRESS_IP/api/users
curl http://$INGRESS_IP/

# Check health
curl http://$INGRESS_IP/api/products/health
curl http://$INGRESS_IP/api/users/health
```

---

## 🎯 **Complete Deployment Workflow**

### **First Time Setup**

```bash
# 1. Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 2. Add repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 3. Get AKS credentials
az aks get-credentials \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev \
  --admin

# 4. Update dependencies
cd helm/ecommerce
helm dependency update

# 5. Deploy
helm install ecommerce . \
  -n ecommerce \
  --create-namespace \
  -f values-dev.yaml

# 6. Verify
kubectl get pods -n ecommerce
helm status ecommerce -n ecommerce
```

---

### **Update Application**

```bash
# 1. Build new images (via pipeline or manually)

# 2. Upgrade with new tags
helm upgrade ecommerce ./helm/ecommerce \
  -n ecommerce \
  -f values-dev.yaml \
  --set productService.image.tag=v1.1.0

# 3. Check status
helm status ecommerce -n ecommerce
kubectl rollout status deployment/ecommerce-product-service -n ecommerce
```

---

### **Rollback on Issues**

```bash
# Check what went wrong
kubectl get pods -n ecommerce
kubectl logs -l app=product-service -n ecommerce

# Rollback
helm rollback ecommerce -n ecommerce

# Verify rollback
helm history ecommerce -n ecommerce
```

---

## 💡 **Pro Tips**

### **1. Use Helm Diff Plugin**

```bash
# Install plugin
helm plugin install https://github.com/databus23/helm-diff

# See what will change before upgrading
helm diff upgrade ecommerce ./helm/ecommerce \
  -n ecommerce \
  -f values-dev.yaml \
  --set productService.replicaCount=5
```

---

### **2. Use --atomic Flag**

```bash
# Automatically rollback on failure
helm upgrade ecommerce ./helm/ecommerce \
  --atomic \
  --timeout 10m

# If upgrade fails, automatically rolls back
```

---

### **3. Use --wait Flag**

```bash
# Wait for all resources to be ready
helm install ecommerce ./helm/ecommerce \
  --wait \
  --timeout 10m

# Helm waits until all pods are running
```

---

## 🐛 **Troubleshooting**

### **Helm Install Fails**

```bash
# Get detailed error
helm install ecommerce ./helm/ecommerce --debug

# Check what would be created
helm template ecommerce ./helm/ecommerce --debug

# Validate chart
helm lint ./helm/ecommerce
```

---

### **Dependencies Not Found**

```bash
# Update dependencies
helm dependency update ./helm/ecommerce

# Build dependencies
helm dependency build ./helm/ecommerce

# List dependencies
helm dependency list ./helm/ecommerce
```

---

### **Release in Bad State**

```bash
# Delete the release
helm uninstall ecommerce -n ecommerce

# Or force delete
helm delete ecommerce -n ecommerce --no-hooks

# Clean reinstall
helm install ecommerce ./helm/ecommerce -n ecommerce -f values-dev.yaml
```

---

## 📚 **Helm Commands Cheat Sheet**

```bash
# Install
helm install <release> <chart> -n <namespace>

# Upgrade
helm upgrade <release> <chart> -n <namespace>

# Install or upgrade (idempotent)
helm upgrade --install <release> <chart> -n <namespace>

# Uninstall
helm uninstall <release> -n <namespace>

# List releases
helm list -n <namespace>

# Get status
helm status <release> -n <namespace>

# Get values
helm get values <release> -n <namespace>

# Get manifest
helm get manifest <release> -n <namespace>

# History
helm history <release> -n <namespace>

# Rollback
helm rollback <release> <revision> -n <namespace>

# Test
helm test <release> -n <namespace>
```

---

## ✅ **Verification Checklist**

After deployment, verify:

- [ ] All pods running (2/2 or 1/1)
- [ ] Services created
- [ ] Ingress has external IP
- [ ] PostgreSQL ready
- [ ] Redis ready
- [ ] RabbitMQ ready
- [ ] Application accessible
- [ ] Health endpoints returning 200
- [ ] HPAs created
- [ ] Secrets exist

```bash
# Quick check all
kubectl get all,ingress,hpa,secrets -n ecommerce
```

---

## 🎓 **Learning Exercises**

### **Exercise 1: Deploy to Dev**

1. Deploy using Helm
2. Verify all components
3. Test the application
4. Check Helm status

### **Exercise 2: Upgrade Image**

1. Change image tag in values
2. Helm upgrade
3. Watch rolling update
4. Verify new version

### **Exercise 3: Rollback**

1. Deploy bad configuration
2. See it fail
3. Helm rollback
4. Application restored

### **Exercise 4: Scale Services**

1. Change replica count
2. Helm upgrade
3. Watch pods scale
4. See in Helm diff

---

## 📋 **Helm vs Raw Manifests**

| Aspect           | Raw Manifests          | Helm Chart           |
| ---------------- | ---------------------- | -------------------- |
| **Deployment**   | Multiple kubectl apply | One helm install     |
| **Environments** | Separate files         | One chart + values   |
| **Updates**      | Manual tracking        | Automated versioning |
| **Rollback**     | kubectl rollout        | helm rollback        |
| **Dependencies** | Manual                 | Automatic            |
| **Templating**   | No                     | Yes                  |
| **Package**      | Folder of YAMLs        | Single .tgz          |

---

## 🚀 **Next Steps**

1. ✅ Create the Helm chart structure
2. ✅ Copy all template files
3. ✅ Update dependencies
4. ✅ Deploy to dev environment
5. ✅ Import Azure DevOps pipeline
6. ✅ Test upgrade and rollback
7. ✅ Create staging and prod value files

---

## 📚 **Additional Resources**

- **Helm Docs:** https://helm.sh/docs/
- **Chart Development:** https://helm.sh/docs/chart_template_guide/
- **Best Practices:** https://helm.sh/docs/chart_best_practices/
- **Bitnami Charts:** https://github.com/bitnami/charts

---

**Deploy your entire microservices stack with one command using Helm!** 🎉
