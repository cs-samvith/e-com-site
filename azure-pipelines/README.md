# Azure DevOps CI/CD Pipelines

This directory contains Azure DevOps YAML pipelines for deploying the e-commerce microservices to Azure Kubernetes Service (AKS).

---

## 📁 Pipelines

### 1. **infrastructure-pipeline.yml**

Deploys Azure infrastructure using Bicep templates.

**Triggers:**

- Push to `main` branch (infrastructure changes)
- Manual run

**Stages:**

- Validate: Validates Bicep template
- Deploy: Deploys AKS, ACR, networking
- Destroy: Deletes infrastructure (requires manual approval)

### 2. **build-and-push-pipeline.yml**

Builds Docker images and pushes to ACR.

**Triggers:**

- Push to `main` branch (service code changes)
- Manual run

**Stages:**

- Build: Builds Docker images for all services
- Publish: Publishes build artifacts

### 3. **deploy-to-aks-pipeline.yml**

Deploys applications to AKS cluster.

**Triggers:**

- Manual run only

**Stages:**

- PreDeploy: Validates cluster
- DeployDataLayer: Deploys PostgreSQL, Redis, RabbitMQ
- DeployServices: Deploys microservices
- ConfigureIngress: Configures ingress
- HealthCheck: Verifies deployment

---

## 🚀 Setup Instructions

### Step 1: Create Azure DevOps Project

1. Go to https://dev.azure.com
2. Create a new project: "ecommerce-aks"
3. Enable pipelines

### Step 2: Create Service Connection

#### Azure Resource Manager Connection

1. Project Settings → Service connections
2. Click "New service connection"
3. Select "Azure Resource Manager"
4. Select "Service principal (automatic)"
5. Choose your subscription
6. Name it: `azure-ecommerce-sp`
7. Click "Save"

#### Docker Registry Connection (ACR)

1. After infrastructure is deployed, create ACR connection
2. Project Settings → Service connections
3. Click "New service connection"
4. Select "Docker Registry"
5. Select "Azure Container Registry"
6. Choose your ACR
7. Name it: `acr-ecommerce`
8. Click "Save"

### Step 3: Create Pipeline Variables

Go to Pipelines → Library → Variable groups

Create a variable group: **ecommerce-secrets**

Add these variables:

| Variable            | Value                    | Secret? |
| ------------------- | ------------------------ | ------- |
| `POSTGRES_PASSWORD` | Generate strong password | ✅ Yes  |
| `RABBITMQ_PASSWORD` | Generate strong password | ✅ Yes  |
| `JWT_SECRET`        | Generate strong password | ✅ Yes  |

**Generate secure passwords:**

```bash
# Using openssl
openssl rand -base64 32

# Using PowerShell
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

### Step 4: Link Variable Group to Pipelines

In each pipeline YAML, add at the top:

```yaml
variables:
  - group: ecommerce-secrets
```

### Step 5: Create Environments

Go to Pipelines → Environments

Create three environments:

- **dev** (no approvals)
- **staging** (1 approver required)
- **prod** (2 approvers required)

---

## 📋 Running Pipelines

### 1. Deploy Infrastructure

1. Go to Pipelines
2. Select "infrastructure-pipeline"
3. Click "Run pipeline"
4. Set parameters:
   - Environment: `dev`
   - Action: `deploy`
5. Click "Run"

⏱️ Takes ~15 minutes

### 2. Build and Push Images

1. Go to Pipelines
2. Select "build-and-push-pipeline"
3. Click "Run pipeline"
4. Set parameters:
   - Environment: `dev`
5. Click "Run"

⏱️ Takes ~5-10 minutes

### 3. Deploy to AKS

1. Go to Pipelines
2. Select "deploy-to-aks-pipeline"
3. Click "Run pipeline"
4. Set parameters:
   - Environment: `dev`
   - Image Tag: `latest` (or specific build number)
5. Click "Run"

⏱️ Takes ~10-15 minutes

---

## 🔄 Complete Workflow

### First Time Setup

```
1. Infrastructure Pipeline (manual)
   ↓
2. Build Pipeline (manual)
   ↓
3. Deploy Pipeline (manual)
```

### Continuous Deployment

After initial setup, pushes to `main` automatically trigger:

```
Code Push → Build Pipeline → (manual approval) → Deploy Pipeline
```

---

## 📊 Pipeline Configuration

### Infrastructure Pipeline

```yaml
# infrastructure-pipeline.yml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - infrastructure/bicep/*

parameters:
  - name: environment
    values:
      - dev
      - staging
      - prod
  - name: action
    values:
      - deploy
      - destroy
```

### Build Pipeline

```yaml
# build-and-push-pipeline.yml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - services/*

parameters:
  - name: environment
    values:
      - dev
      - staging
      - prod
```

### Deploy Pipeline

```yaml
# deploy-to-aks-pipeline.yml
trigger: none # Manual only

parameters:
  - name: environment
    values:
      - dev
      - staging
      - prod
  - name: imageTag
    default: "latest"
```

---

## 🔐 Security Best Practices

### Service Connections

✅ **DO:**

- Use managed identities when possible
- Limit scope to specific resource groups
- Create separate connections per environment
- Regularly review and rotate credentials

❌ **DON'T:**

- Use personal accounts
- Share service principals across projects
- Grant subscription-level permissions unnecessarily

### Secrets Management

✅ **DO:**

- Store all secrets in Azure Key Vault or Pipeline Variables
- Mark variables as "Secret"
- Use variable groups
- Rotate secrets regularly

❌ **DON'T:**

- Commit secrets to repository
- Log secret values
- Share secrets via email/chat

---

## 🐛 Troubleshooting

### Pipeline Fails: "Service connection not found"

**Solution:**

1. Go to Project Settings → Service connections
2. Verify connection name matches YAML (`azure-ecommerce-sp`)
3. Test connection
4. Grant access to all pipelines

### Pipeline Fails: "Insufficient permissions"

**Solution:**

```bash
# Get service principal ID
$spId = az ad sp list --display-name "azure-ecommerce-sp" --query "[0].id" -o tsv

# Grant Contributor role
az role assignment create \
  --assignee $spId \
  --role Contributor \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

### Cannot Push to ACR

**Solution:**

1. Verify ACR service connection is created
2. Check ACR connection is selected in Docker@2 tasks
3. Verify AKS has AcrPull role on ACR

### Secrets Not Found

**Solution:**

1. Verify variable group "ecommerce-secrets" exists
2. Check variables are marked as secret
3. Verify pipeline references variable group:

```yaml
variables:
  - group: ecommerce-secrets
```

### Deployment Stuck

**Solution:**

```bash
# Check pod status
kubectl get pods -n ecommerce

# View pod logs
kubectl logs <POD_NAME> -n ecommerce

# Describe pod
kubectl describe pod <POD_NAME> -n ecommerce
```

---

## 📈 Pipeline Monitoring

### View Pipeline Runs

1. Go to Pipelines
2. Select pipeline
3. Click on run number
4. View stages, jobs, and logs

### Pipeline Analytics

1. Go to Pipelines → Analytics
2. View metrics:
   - Success rate
   - Duration trends
   - Failure reasons

### Enable Notifications

1. Project Settings → Notifications
2. Create subscription for:
   - Build completed
   - Release deployment failed
   - Release deployment succeeded

---

## 🔄 Rollback Strategy

### Rollback to Previous Build

1. Go to Pipelines → deploy-to-aks-pipeline
2. Click "Run pipeline"
3. Set Image Tag to previous build number
4. Run deployment

### Manual Kubectl Rollback

```bash
# Connect to cluster
az aks get-credentials --resource-group rg-ecommerce-aks-dev --name aks-ecommerce-dev

# Rollback deployments
kubectl rollout undo deployment/product-service -n ecommerce
kubectl rollout undo deployment/user-service -n ecommerce
kubectl rollout undo deployment/frontend-service -n ecommerce

# Check rollout status
kubectl rollout status deployment/product-service -n ecommerce
```

---

## 📚 Additional Resources

- [Azure Pipelines Documentation](https://docs.microsoft.com/en-us/azure/devops/pipelines/)
- [YAML Schema Reference](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)

---

## 🎯 Best Practices

### Pipeline Organization

- One pipeline per concern (infra, build, deploy)
- Use stages for logical grouping
- Implement approval gates for production
- Use templates for reusable components

### Build Optimization

- Use Docker layer caching
- Build only changed services
- Run tests in parallel
- Cache dependencies

### Deployment Strategy

- Deploy to dev automatically
- Require approval for staging/prod
- Use canary or blue-green for production
- Always have rollback plan

---

## ✅ Checklist

Before running pipelines:

- [ ] Azure DevOps project created
- [ ] Service connections configured
- [ ] Variable group created with secrets
- [ ] Environments created (dev/staging/prod)
- [ ] Pipelines imported from YAML
- [ ] Variable groups linked to pipelines
- [ ] Approval gates configured
- [ ] Notifications enabled

---

Happy deploying with Azure DevOps! 🚀
