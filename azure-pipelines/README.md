# Azure DevOps Pipelines - Complete Guide

This directory contains all Azure DevOps YAML pipelines for the e-commerce microservices project.

---

## 📁 Files

| File                          | Purpose                   | Trigger                      |
| ----------------------------- | ------------------------- | ---------------------------- |
| `infrastructure-pipeline.yml` | Deploy AKS infrastructure | Manual only                  |
| `build-and-push-pipeline.yml` | Build Docker images       | Code changes in `services/*` |
| `deploy-to-aks-pipeline.yml`  | Deploy to Kubernetes      | Manual or after build        |

---

## 🚀 Setup Instructions

### Step 1: Create Service Connection

1. Go to Azure DevOps → Project Settings → Service connections
2. Click "New service connection"
3. Select "Azure Resource Manager"
4. Select "Service principal (automatic)"
5. Choose your subscription
6. Name it: `azure-ecommerce-sp`
7. Click "Save"

### Step 2: Create Variable Group

1. Go to Pipelines → Library → Variable groups
2. Click "+ Variable group"
3. Name: `ecommerce-secrets`
4. Add these variables:

| Variable            | Value                                    | Secret? |
| ------------------- | ---------------------------------------- | ------- |
| `POSTGRES_PASSWORD` | Generate with: `openssl rand -base64 32` | ✅ Yes  |
| `RABBITMQ_PASSWORD` | Generate with: `openssl rand -base64 32` | ✅ Yes  |
| `JWT_SECRET`        | Generate with: `openssl rand -base64 32` | ✅ Yes  |

5. Click "Save"

### Step 3: Create Environments

1. Go to Pipelines → Environments
2. Create three environments:
   - **dev** (no approvals)
   - **staging** (1 approver)
   - **prod** (2 approvers)

### Step 4: Import Pipelines

For each pipeline file:

1. Go to Pipelines → Pipelines
2. Click "New pipeline"
3. Select "Azure Repos Git" (or GitHub)
4. Select your repository
5. Choose "Existing Azure Pipelines YAML file"
6. Select the file:
   - `/azure-pipelines/infrastructure-pipeline.yml`
   - `/azure-pipelines/build-and-push-pipeline.yml`
   - `/azure-pipelines/deploy-to-aks-pipeline.yml`
7. Click "Continue"
8. Click "Save" (don't run yet)

### Step 5: Rename Pipelines

After creating each pipeline:

1. Click the three dots (⋯) → Rename/move
2. Rename to:
   - "Deploy Infrastructure"
   - "Build and Push Images"
   - "Deploy to AKS"
3. Click "Save"

### Step 6: Configure Pipeline Triggers (Optional)

To make the Deploy pipeline auto-trigger after Build:

1. Open `azure-pipelines/deploy-to-aks-pipeline.yml`
2. Find the commented `resources` section at the top
3. Uncomment it
4. Update the `source` value to match your build pipeline name exactly
5. Commit and push

Example:

```yaml
resources:
  pipelines:
    - pipeline: buildPipeline
      source: "Build and Push Images" # Must match exactly
      trigger:
        branches:
          include:
            - main
```

---

## 🎯 Usage Workflow

### First Time Setup

```
Step 1: Deploy Infrastructure (ONCE)
  └─ Run: "Deploy Infrastructure" pipeline
  └─ Takes: 10-15 minutes
  └─ Creates: AKS cluster, ACR, networking

Step 2: Build Images (ONCE)
  └─ Run: "Build and Push Images" pipeline
  └─ Takes: 5-10 minutes
  └─ Creates: Docker images in ACR

Step 3: Deploy Applications (ONCE)
  └─ Run: "Deploy to AKS" pipeline
  └─ Takes: 5-10 minutes
  └─ Deploys: All services to Kubernetes
```

### Development Workflow

```
Day 1: Infrastructure deployed ✅

Day 2-N: Code changes
  1. Edit code in services/
  2. Commit and push
  3. "Build and Push Images" runs automatically ✅
  4. "Deploy to AKS" runs automatically ✅
  5. Application updated! 🎉
```

---

## 📋 Pipeline Details

### 1. Infrastructure Pipeline

**When to run:**

- ❌ Don't run if cluster already exists
- ✅ Run once to create initial infrastructure
- ✅ Run when changing cluster configuration

**What it does:**

1. Checks if cluster already exists
2. Registers Azure providers
3. Validates Bicep template
4. Deploys AKS cluster
5. Configures ACR permissions

**Parameters:**

- `environment`: dev/staging/prod
- `action`: deploy/destroy

### 2. Build and Push Pipeline

**When to run:**

- ✅ Automatically on code changes
- ✅ Manually when needed

**What it does:**

1. Builds Docker images using `az acr build`
2. Tags images with build number + latest
3. Pushes to Azure Container Registry
4. Verifies images

**Parameters:**

- `environment`: dev/staging/prod
- `services`: Which services to build

### 3. Deploy to AKS Pipeline

**When to run:**

- ✅ Automatically after successful build
- ✅ Manually to update applications

**What it does:**

1. Validates cluster health
2. Deploys data layer (PostgreSQL, Redis, RabbitMQ)
3. Deploys microservices
4. Configures ingress
5. Runs health checks

**Parameters:**

- `environment`: dev/staging/prod
- `imageTag`: Which image version to deploy

---

## 🔐 Security Best Practices

### Variable Groups

- ✅ Use variable groups for secrets
- ✅ Mark sensitive values as "Secret"
- ✅ Rotate secrets regularly
- ❌ Never commit secrets to repository

### Service Connections

- ✅ Use managed identities when possible
- ✅ Limit scope to specific resource groups
- ✅ Create separate connections per environment
- ❌ Don't use personal accounts

### Environments

- ✅ Require approvals for production
- ✅ Use environment-specific secrets
- ✅ Configure deployment gates
- ❌ Don't bypass approvals

---

## 🐛 Troubleshooting

### Pipeline fails: "Service connection not found"

**Solution:**

1. Go to Project Settings → Service connections
2. Verify connection name is exactly: `azure-ecommerce-sp`
3. Test the connection
4. Grant access to all pipelines

### Pipeline fails: "AKS cluster not found"

**Solution:**

1. Check if infrastructure pipeline completed successfully
2. Verify resource group exists
3. Run infrastructure pipeline if needed

### Pipeline fails: "Secrets not found"

**Solution:**

1. Go to Pipelines → Library
2. Verify variable group "ecommerce-secrets" exists
3. Verify all three secrets are defined
4. Link variable group to pipeline

### Images fail to build

**Solution:**

1. Check ACR exists in resource group
2. Verify Dockerfile syntax
3. Check service connection permissions

### Deployment fails: "ControlPlaneNotFound"

**Solution:**

- Cluster is in broken state
- Delete resource group and redeploy infrastructure

---

## 📊 Pipeline Monitoring

### View Pipeline Runs

1. Go to Pipelines → Pipelines
2. Click on pipeline name
3. View run history

### View Logs

1. Click on a pipeline run
2. Click on stage/job
3. View detailed logs

### Cancel Running Pipeline

1. Open running pipeline
2. Click three dots (⋯)
3. Click "Cancel"

---

## 🔄 Updating Pipelines

### Modify Pipeline YAML

1. Edit the YAML file in repository
2. Commit and push
3. Pipeline automatically uses new version

### Test Pipeline Changes

1. Create a feature branch
2. Modify pipeline YAML
3. Trigger pipeline from feature branch
4. Merge to main when tested

---

## 📈 Best Practices

### Infrastructure Pipeline

- ✅ Run manually, not on every commit
- ✅ Add approval gates for production
- ✅ Document infrastructure changes

### Build Pipeline

- ✅ Auto-trigger on code changes
- ✅ Build only changed services if possible
- ✅ Tag images with build number

### Deploy Pipeline

- ✅ Deploy automatically to dev
- ✅ Require approval for staging/prod
- ✅ Use health checks
- ✅ Keep rollback capability

---

## ✅ Checklist

Before running pipelines:

- [ ] Service connection created (`azure-ecommerce-sp`)
- [ ] Variable group created (`ecommerce-secrets`)
- [ ] All three secrets added to variable group
- [ ] Environments created (dev, staging, prod)
- [ ] All three pipelines imported
- [ ] Pipelines renamed for clarity
- [ ] Variable groups linked to pipelines

---

## 🎓 Additional Resources

- [Azure Pipelines Documentation](https://docs.microsoft.com/en-us/azure/devops/pipelines/)
- [YAML Schema Reference](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)

---

Happy deploying! 🚀
