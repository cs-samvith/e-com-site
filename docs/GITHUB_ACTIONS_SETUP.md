# GitHub Actions Setup Guide for Terraform

Complete guide to set up automated Terraform deployments using GitHub Actions.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Create Azure Service Principals](#create-azure-service-principals)
3. [Set Up Remote State Storage](#set-up-remote-state-storage)
4. [Configure GitHub Secrets](#configure-github-secrets)
5. [Configure GitHub Environments](#configure-github-environments)
6. [Test the Workflow](#test-the-workflow)
7. [Workflow Triggers](#workflow-triggers)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- ✅ Azure subscription with sufficient permissions
- ✅ GitHub repository with Terraform code
- ✅ Azure CLI installed locally
- ✅ GitHub CLI installed (optional)

---

## 1. Create Azure Service Principals

Create separate service principals for each environment.

### Step 1: Login to Azure

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### Step 2: Create Service Principals

#### For Development

```bash
# Set variables
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
APP_NAME="sp-terraform-ecommerce-dev"

# Create service principal
az ad sp create-for-rbac \
  --name $APP_NAME \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth > dev-credentials.json

# View the output (save this!)
cat dev-credentials.json
```

#### For Staging

```bash
APP_NAME="sp-terraform-ecommerce-staging"

az ad sp create-for-rbac \
  --name $APP_NAME \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth > staging-credentials.json

cat staging-credentials.json
```

#### For Production

```bash
APP_NAME="sp-terraform-ecommerce-prod"

az ad sp create-for-rbac \
  --name $APP_NAME \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth > prod-credentials.json

cat prod-credentials.json
```

**Output format:**

```json
{
  "clientId": "xxxx-xxxx-xxxx-xxxx",
  "clientSecret": "xxxx-xxxx-xxxx-xxxx",
  "subscriptionId": "xxxx-xxxx-xxxx-xxxx",
  "tenantId": "xxxx-xxxx-xxxx-xxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

**⚠️ Security Note:** Keep these credentials secure! Delete the JSON files after adding to GitHub Secrets.

```bash
# After adding to GitHub Secrets
rm dev-credentials.json staging-credentials.json prod-credentials.json
```

---

## 2. Set Up Remote State Storage

Terraform state needs to be stored remotely for collaboration.

### Create Storage Account

```bash
# Variables
RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="tfstate$(date +%s)"  # Must be globally unique
CONTAINER_NAME="tfstate"
LOCATION="eastus"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --encryption-services blob \
  --allow-blob-public-access false

# Get account key
ACCOUNT_KEY=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP \
  --account-name $STORAGE_ACCOUNT \
  --query '[0].value' -o tsv)

# Create container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT \
  --account-key $ACCOUNT_KEY

# Save these values for GitHub Secrets
echo "TF_STATE_RESOURCE_GROUP=$RESOURCE_GROUP"
echo "TF_STATE_STORAGE_ACCOUNT=$STORAGE_ACCOUNT"
echo "TF_STATE_CONTAINER=$CONTAINER_NAME"
```

### Grant Service Principals Access

```bash
# Get storage account ID
STORAGE_ID=$(az storage account show \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --query id -o tsv)

# Grant access to each service principal
for ENV in dev staging prod; do
  SP_ID=$(az ad sp list --display-name "sp-terraform-ecommerce-$ENV" --query [0].id -o tsv)

  az role assignment create \
    --assignee $SP_ID \
    --role "Storage Blob Data Contributor" \
    --scope $STORAGE_ID
done
```

---

## 3. Configure GitHub Secrets

Add secrets to your GitHub repository.

### Via GitHub Web UI

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add the following secrets:

### Required Secrets

#### Azure Service Principal Credentials

| Secret Name                 | Value                                  | Description                        |
| --------------------------- | -------------------------------------- | ---------------------------------- |
| `AZURE_CREDENTIALS_DEV`     | Contents of `dev-credentials.json`     | Dev environment credentials        |
| `AZURE_CREDENTIALS_STAGING` | Contents of `staging-credentials.json` | Staging environment credentials    |
| `AZURE_CREDENTIALS_PROD`    | Contents of `prod-credentials.json`    | Production environment credentials |

#### Terraform State Storage

| Secret Name                | Value                | Description                       |
| -------------------------- | -------------------- | --------------------------------- |
| `TF_STATE_RESOURCE_GROUP`  | Resource group name  | Where state storage account lives |
| `TF_STATE_STORAGE_ACCOUNT` | Storage account name | State storage account             |
| `TF_STATE_CONTAINER`       | Container name       | Usually "tfstate"                 |

#### Optional: Cost Estimation

| Secret Name         | Value                  | Description                |
| ------------------- | ---------------------- | -------------------------- |
| `INFRACOST_API_KEY` | Your Infracost API key | For cost estimation in PRs |

Get Infracost API key at: https://www.infracost.io/

### Via GitHub CLI (Alternative)

```bash
# Install GitHub CLI
# macOS: brew install gh
# Windows: winget install GitHub.cli

# Login to GitHub
gh auth login

# Set repository (replace with your repo)
REPO="your-username/your-repo"

# Add secrets
gh secret set AZURE_CREDENTIALS_DEV --body-file dev-credentials.json --repo $REPO
gh secret set AZURE_CREDENTIALS_STAGING --body-file staging-credentials.json --repo $REPO
gh secret set AZURE_CREDENTIALS_PROD --body-file prod-credentials.json --repo $REPO

gh secret set TF_STATE_RESOURCE_GROUP --body "$RESOURCE_GROUP" --repo $REPO
gh secret set TF_STATE_STORAGE_ACCOUNT --body "$STORAGE_ACCOUNT" --repo $REPO
gh secret set TF_STATE_CONTAINER --body "$CONTAINER_NAME" --repo $REPO

# Optional: Infracost
gh secret set INFRACOST_API_KEY --body "YOUR_INFRACOST_KEY" --repo $REPO
```

---

## 4. Configure GitHub Environments

Environments provide deployment protection rules.

### Via GitHub Web UI

1. Go to **Settings** → **Environments**
2. Create three environments: `dev`, `staging`, `prod`

#### Development Environment

- **Name:** `dev`
- **Protection rules:**
  - ✅ Required reviewers: 0 (auto-deploy)
  - ⏱️ Wait timer: 0 minutes

#### Staging Environment

- **Name:** `staging`
- **Protection rules:**
  - ✅ Required reviewers: 1 (yourself or team lead)
  - ⏱️ Wait timer: 0 minutes
  - ✅ Restrict deployments to: `main` branch

#### Production Environment

- **Name:** `prod`
- **Protection rules:**
  - ✅ Required reviewers: 2 (senior team members)
  - ⏱️ Wait timer: 5 minutes (cooling period)
  - ✅ Restrict deployments to: `main` branch
  - ✅ Prevent self-review: Enabled

### Environment Secrets (Optional)

You can also add environment-specific secrets:

1. Go to **Settings** → **Environments** → Select environment
2. Click **Add secret**
3. Add any environment-specific values

---

## 5. Enable Backend in main.tf

Update your `main.tf` to use the remote backend:

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Enable remote backend
  backend "azurerm" {
    # Backend config is provided via GitHub Actions
    # Values: resource_group_name, storage_account_name, container_name, key
  }
}
```

The backend configuration is provided dynamically in the workflow.

---

## 6. Test the Workflow

### Test 1: Create Pull Request

```bash
# Create a feature branch
git checkout -b feature/test-terraform

# Make a small change
echo "# Test change" >> infrastructure/terraform/README.md

# Commit and push
git add .
git commit -m "test: Verify Terraform workflow"
git push origin feature/test-terraform

# Create PR on GitHub
gh pr create --title "Test Terraform Workflow" --body "Testing automated deployment"
```

**Expected results:**

- ✅ Validation job runs
- ✅ Security scan runs
- ✅ Cost estimation appears in PR comment
- ✅ Dev plan appears in PR comment
- ❌ Apply jobs DO NOT run (PR only)

### Test 2: Merge to Main (Dev Auto-Deploy)

```bash
# Merge PR
gh pr merge --squash

# Wait for workflow
gh run watch
```

**Expected results:**

- ✅ Validation runs
- ✅ Security scan runs
- ✅ Dev plan runs
- ✅ Dev apply runs (auto-deploys)
- ✅ Staging plan runs
- ⏸️ Staging apply waits for approval

### Test 3: Manual Workflow Dispatch

```bash
# Trigger workflow manually
gh workflow run terraform-deploy.yml \
  --field environment=staging \
  --field action=plan

# Watch the run
gh run watch
```

---

## 7. Workflow Triggers

### Automatic Triggers

#### Pull Request

```
Trigger: Pull request to main branch
Changes: infrastructure/terraform/**
Runs:
  ✅ Validation
  ✅ Security scanning
  ✅ Cost estimation
  ✅ Dev plan (comment on PR)
  ❌ No apply
```

#### Push to Main

```
Trigger: Push to main branch
Changes: infrastructure/terraform/**
Runs:
  ✅ Validation
  ✅ Security scanning
  ✅ Dev plan + apply (auto)
  ✅ Staging plan
  ⏸️ Staging apply (requires approval)
  ❌ Production (manual only)
```

### Manual Triggers

#### Deploy to Environment

```bash
# Via GitHub UI: Actions → Terraform Infrastructure Deployment → Run workflow
# Choose:
#   - Environment: dev/staging/prod
#   - Action: plan/apply/destroy

# Via GitHub CLI
gh workflow run terraform-deploy.yml \
  --field environment=staging \
  --field action=apply
```

#### Destroy Infrastructure

```bash
# Via GitHub UI: Actions → Terraform Infrastructure Destroy → Run workflow
# Enter:
#   - Environment: dev/staging/prod
#   - Confirmation: DESTROY

# Via GitHub CLI
gh workflow run terraform-destroy.yml \
  --field environment=dev \
  --field confirmation=DESTROY
```

---

## 8. Workflow Features

### ✅ Validation

- Terraform format checking
- Terraform validation
- Syntax checking

### 🔒 Security Scanning

- **Checkov**: Comprehensive policy checks
- **tfsec**: Terraform-specific security scanner
- Results uploaded to GitHub Security tab

### 💰 Cost Estimation

- **Infracost**: Shows cost changes in PRs
- Compares before/after costs
- Helps make informed decisions

### 📝 Plan Artifacts

- Plans saved as artifacts
- Available for 7 days
- Used for apply step

### 🔐 Environment Protection

- **Dev**: Auto-deploys
- **Staging**: Requires 1 approval
- **Prod**: Requires 2 approvals + 5 min wait

### 📊 Deployment Summaries

- Shows deployment status
- Displays resource information
- Provides connection commands

---

## 9. Troubleshooting

### Error: "Backend initialization failed"

**Cause:** Service principal doesn't have access to storage account

**Solution:**

```bash
# Grant Storage Blob Data Contributor role
STORAGE_ID=$(az storage account show \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --query id -o tsv)

SP_ID=$(az ad sp list --display-name "sp-terraform-ecommerce-dev" --query [0].id -o tsv)

az role assignment create \
  --assignee $SP_ID \
  --role "Storage Blob Data Contributor" \
  --scope $STORAGE_ID
```

### Error: "Insufficient privileges"

**Cause:** Service principal needs more permissions

**Solution:**

```bash
# Grant Contributor role at subscription level
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SP_ID=$(az ad sp list --display-name "sp-terraform-ecommerce-dev" --query [0].id -o tsv)

az role assignment create \
  --assignee $SP_ID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID
```

### Error: "Resource provider not registered"

**Solution:**

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Compute
```

### Error: "State lock"

**Cause:** Previous workflow didn't complete properly

**Solution:**

```bash
# Force unlock (use carefully!)
terraform force-unlock LOCK_ID
```

### Workflow not triggering

**Check:**

1. Workflow file path: `.github/workflows/terraform-deploy.yml`
2. File changes match trigger paths
3. Branch name matches trigger
4. Secrets are correctly configured

### Cost estimation not working

**Check:**

1. `INFRACOST_API_KEY` secret is set
2. Infracost API key is valid
3. Only runs on pull requests

---

## 10. Best Practices

### Security

- ✅ Use separate service principals per environment
- ✅ Rotate service principal secrets regularly (every 90 days)
- ✅ Enable soft delete on storage account
- ✅ Use Azure Key Vault for sensitive values
- ✅ Never commit credentials to git

### State Management

- ✅ Enable blob versioning on storage account
- ✅ Enable soft delete on blobs
- ✅ Use separate state files per environment
- ✅ Enable state locking

### Deployment

- ✅ Always run plan before apply
- ✅ Review plans carefully for production
- ✅ Use environment protection rules
- ✅ Test in dev/staging before production
- ✅ Keep Terraform version pinned

### Monitoring

- ✅ Set up Azure Monitor for deployed resources
- ✅ Configure cost alerts
- ✅ Review security scan results
- ✅ Monitor workflow execution times

---

## 11. Advanced Configuration

### Enable Branch Protection

```bash
# Via GitHub CLI
gh api repos/$REPO/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["validate","security"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}'
```

### Add Slack Notifications

Add to workflow:

```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Terraform deployment ${{ job.status }}"
      }
```

### Add CODEOWNERS

Create `.github/CODEOWNERS`:

```
# Terraform changes require DevOps team approval
infrastructure/terraform/** @your-org/devops-team
```

---

## Summary Checklist

Before first deployment:

- [ ] Azure service principals created for all environments
- [ ] Remote state storage account created
- [ ] All GitHub secrets configured
- [ ] GitHub environments configured with protection rules
- [ ] Backend configuration enabled in main.tf
- [ ] Workflow files committed to `.github/workflows/`
- [ ] Tested with a pull request
- [ ] Reviewed and approved by team

---

## Support

For issues:

1. Check workflow logs in GitHub Actions
2. Review Azure Portal for resource status
3. Check Terraform state in storage account
4. Review this troubleshooting guide

Happy deploying! 🚀
