# Azure Kubernetes Service - Cost Guide

Understanding and optimizing costs for your AKS deployment.

---

## 💰 Cost Breakdown

### 1. AKS Cluster Management

- **Cost:** FREE
- AKS control plane is free, you only pay for the nodes

### 2. Virtual Machines (Nodes)

**Standard_D2s_v3 (Recommended for this project)**

- **vCPUs:** 2
- **RAM:** 8 GB
- **Cost:** ~$96/month per node (East US, Pay-as-you-go)
- **For 3 nodes:** ~$288/month

**Other Options:**

- Standard_B2s: ~$30/month (Dev/Test, limited performance)
- Standard_D4s_v3: ~$192/month (Higher performance)

### 3. Managed Disks (Storage)

- **OS Disk (per node):** 128GB Premium SSD ~$19/month
- **PostgreSQL PVC:** 5GB Premium SSD ~$1/month
- **RabbitMQ PVC:** 2GB Premium SSD ~$0.40/month
- **Total for 3 nodes + PVCs:** ~$60/month

### 4. Load Balancer / Application Gateway

- **Standard Load Balancer:** ~$22/month + data processing
- **Application Gateway v2:** ~$230/month (includes WAF features)

### 5. Container Registry (ACR)

- **Standard SKU:** ~$20/month (100 GB storage)
- **Premium SKU:** ~$500/month (recommended for production)

### 6. Networking

- **Egress traffic:** First 5GB free, then $0.087/GB
- **Expected:** ~$10-20/month for moderate traffic

### 7. Azure Monitor (Optional)

- **Log Analytics:** ~$2.30/GB ingested
- **Expected:** ~$20-50/month for basic monitoring

---

## 📊 Estimated Monthly Costs

### Development/Learning Environment

```
AKS Nodes (2x Standard_B2s):     $60
Managed Disks:                     $40
Basic Load Balancer:               $22
ACR Standard:                      $20
Networking:                        $10
Azure Monitor (basic):             $20
─────────────────────────────────────
TOTAL:                           ~$172/month
```

### Production Environment

```
AKS Nodes (3x Standard_D2s_v3):  $288
Managed Disks:                     $60
Application Gateway v2:           $230
ACR Premium:                       $20
Networking:                        $30
Azure Monitor (full):              $50
─────────────────────────────────────
TOTAL:                           ~$678/month
```

---

## 💡 Cost Optimization Strategies

### 1. Use Azure Dev/Test Pricing (If Eligible)

Save up to 55% on VMs with Visual Studio subscription or Enterprise Agreement.

```bash
# Check eligibility
az account show --query "name"
```

### 2. Auto-Shutdown During Non-Business Hours

**Stop AKS Cluster (Stops VMs, keeps resources):**

```bash
# Stop cluster (evenings/weekends)
az aks stop --name aks-ecommerce --resource-group rg-ecommerce-aks

# Start when needed
az aks start --name aks-ecommerce --resource-group rg-ecommerce-aks
```

**Savings:** ~50% if stopped 12 hours/day = ~$144/month saved on VMs

### 3. Use Azure Spot VMs (Dev/Test Only)

```bash
az aks nodepool add \
  --resource-group rg-ecommerce-aks \
  --cluster-name aks-ecommerce \
  --name spotpool \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1 \
  --node-count 2

# Can save up to 90% on compute costs!
```

**Warning:** Spot VMs can be evicted at any time. Only for non-critical workloads.

### 4. Right-Size Your Nodes

Start with smaller nodes and scale up as needed:

```bash
# For learning/development: B-series
Standard_B2s:  2 vCPU, 4GB RAM  - $30/month
Standard_B2ms: 2 vCPU, 8GB RAM  - $60/month

# For production: D-series
Standard_D2s_v3: 2 vCPU, 8GB RAM   - $96/month
Standard_D4s_v3: 4 vCPU, 16GB RAM  - $192/month
```

### 5. Use Horizontal Pod Autoscaler (HPA)

Already configured in the manifests! This ensures you only use resources when needed.

### 6. Reduce Node Count for Development

```bash
# Scale down to 1 node for development
az aks scale \
  --resource-group rg-ecommerce-aks \
  --name aks-ecommerce \
  --node-count 1

# Scale up for testing
az aks scale \
  --resource-group rg-ecommerce-aks \
  --name aks-ecommerce \
  --node-count 3
```

### 7. Use Standard Load Balancer Instead of Application Gateway

For development, use Standard Load Balancer:

```bash
# Create AKS without Application Gateway
az aks create \
  --resource-group rg-ecommerce-aks \
  --name aks-ecommerce \
  --node-count 2 \
  --node-vm-size Standard_B2ms \
  --enable-managed-identity \
  --attach-acr acrecommerce001 \
  --generate-ssh-keys

# Saves ~$200/month
```

### 8. Use Azure Free Tier Services

- **Azure Monitor:** First 5GB free/month
- **ACR:** First 10GB storage free (use with Basic SKU)
- **Egress:** First 5GB free/month

### 9. Reserved Instances (Production)

For long-term production deployments:

- **1-year reservation:** Save 20-30%
- **3-year reservation:** Save 40-60%

```bash
# Check pricing
az vm list-sizes --location eastus --output table
```

### 10. Delete Resources When Not in Use

```bash
# Stop AKS cluster (keeps configuration)
az aks stop --name aks-ecommerce --resource-group rg-ecommerce-aks

# Delete entire resource group (EVERYTHING gone)
az group delete --name rg-ecommerce-aks --yes
```

---

## 🎓 Recommended Setup for Learning

### Minimal Cost Configuration (~$70-100/month)

```bash
RESOURCE_GROUP="rg-ecommerce-aks-dev"
LOCATION="eastus"
AKS_CLUSTER_NAME="aks-ecommerce-dev"
ACR_NAME="acrecommercedev"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create ACR (Basic tier)
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic

# Create minimal AKS cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --node-count 1 \
  --node-vm-size Standard_B2ms \
  --enable-managed-identity \
  --attach-acr $ACR_NAME \
  --network-plugin kubenet \
  --load-balancer-sku basic \
  --generate-ssh-keys

# Cost breakdown:
# - 1x Standard_B2ms: ~$60/month
# - Managed Disk: ~$20/month
# - Basic Load Balancer: ~$22/month
# - ACR Basic: Free (first 10GB)
# Total: ~$102/month
```

### Stop/Start Schedule for Learning

**Weekday Schedule:**

- Start: 8 AM (before work/study)
- Stop: 6 PM (after work/study)
- Active: 10 hours/day

**Weekend:**

- Completely stopped

**Monthly Savings:** ~60% reduction = ~$60/month instead of $150/month

---

## 📅 Cost Tracking

### Enable Cost Management

```bash
# View costs in Azure Portal
# Navigate to: Cost Management + Billing → Cost Analysis
```

### Set Budget Alerts

```bash
# In Azure Portal:
# 1. Go to Subscriptions
# 2. Select your subscription
# 3. Click "Budgets"
# 4. Create budget with alerts at 50%, 75%, 90%, 100%
```

### Tag Resources for Tracking

```bash
# Tag all resources
az resource tag \
  --tags Environment=Learning Project=Ecommerce \
  --ids $(az resource list --resource-group rg-ecommerce-aks --query "[].id" -o tsv)
```

---

## 🎯 Cost Optimization Checklist

- [ ] Use appropriate VM size (B-series for dev, D-series for prod)
- [ ] Scale node count based on needs (1 for dev, 3+ for prod)
- [ ] Stop AKS cluster when not in use
- [ ] Use Azure Dev/Test pricing if eligible
- [ ] Configure HPA to scale pods dynamically
- [ ] Use Basic/Standard Load Balancer instead of App Gateway for dev
- [ ] Set budget alerts in Azure Portal
- [ ] Monitor costs weekly
- [ ] Consider Spot VMs for non-critical workloads
- [ ] Use ACR Basic tier for learning
- [ ] Delete resources when project is complete

---

## 💳 Azure Free Tier / Credits

### Azure Free Account

- **$200 credit** for 30 days (new users)
- **12 months free** of popular services (limited amounts)
- **Always free** tier for basic services

### Azure for Students

- **$100 credit** (no credit card required)
- Free for 12 months

### GitHub Education

- **Azure credits** for verified students
- Access to GitHub Student Developer Pack

---

## 🚨 Avoid Unexpected Charges

### 1. Set Spending Limit

```bash
# In Azure Portal → Subscriptions → Spending limit: ON
```

### 2. Regular Monitoring

```bash
# Check current month cost
az consumption usage list --query "[?usageEnd>='2024-01-01'].{Service:meterName, Cost:pretaxCost}" -o table
```

### 3. Delete Unused Resources

```bash
# List all resource groups
az group list --output table

# Delete unused resource groups
az group delete --name <RESOURCE_GROUP_NAME> --yes
```

### 4. Watch for Hidden Costs

- Public IP addresses: ~$3-5/month each
- Unused disks: Still charged even if VM is deleted
- Stopped VMs: Disk storage still costs money
- Application Gateway: High fixed cost (~$230/month)

---

## 📞 Need Help with Costs?

**Azure Cost Calculator:**
https://azure.microsoft.com/en-us/pricing/calculator/

**Azure Pricing Support:**

- Open support ticket in Azure Portal
- Community forums: Microsoft Q&A
- StackOverflow: [azure-aks] tag

---

## 🎓 Summary for Learning

**Best Configuration:**

- 1-2 nodes (Standard_B2ms)
- Basic Load Balancer
- ACR Basic
- Stop cluster when not in use
- **Total Cost: ~$70-100/month (or ~$30-40/month with stop/start schedule)**

**Most Expensive Items:**

1. VM compute (nodes)
2. Application Gateway (if used)
3. Managed disks
4. Load balancer

**Biggest Savings:**

1. Stop cluster when not in use (50% savings)
2. Use B-series VMs instead of D-series (70% savings)
3. Use Basic LB instead of App Gateway ($200/month savings)
4. Scale down node count (33% savings per node removed)

---

Happy learning without breaking the bank! 💰
