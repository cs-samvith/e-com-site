# ArgoCD Guide - GitOps for Your E-Commerce Project

Complete guide to implementing GitOps with ArgoCD on your AKS cluster.

---

## 🚀 **Quick Start - Get Started with ArgoCD in 15 Minutes**

### **Prerequisites**

- ✅ AKS cluster running (`aks-ecommerce-dev`)
- ✅ kubectl configured and connected
- ✅ Git repository with your code

---

### **Step 1: Install ArgoCD (5 minutes)**

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

# Check installation
kubectl get pods -n argocd

# Should show 7 pods all Running:
# argocd-application-controller-xxx
# argocd-applicationset-controller-xxx
# argocd-dex-server-xxx
# argocd-notifications-controller-xxx
# argocd-redis-xxx
# argocd-repo-server-xxx
# argocd-server-xxx
```

---

### **Step 2: Access ArgoCD UI (2 minutes)**

```bash
# Get the initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
echo

# Save this password!

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open in browser: https://localhost:8080
# (Accept the self-signed certificate warning)

# Login:
# Username: admin
# Password: <password from above>
```

---

### **Step 3: Change Admin Password (1 minute)**

**In ArgoCD UI:**

1. Click "User Info" (top right)
2. Click "Update Password"
3. Enter new password
4. Save

**Or via CLI:**

```bash
# Install ArgoCD CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
argocd login localhost:8080 --username admin --password <initial-password>

# Change password
argocd account update-password

# Delete the initial secret
kubectl delete secret argocd-initial-admin-secret -n argocd
```

---

### **Step 4: Connect Your Git Repository (2 minutes)**

**Via UI:**

1. Go to **Settings** (gear icon) → **Repositories**
2. Click **"Connect Repo"**
3. Choose method: **HTTPS** or **SSH**
4. Enter repository URL: `https://github.com/yourusername/e-com-site`
5. If private:
   - Username: your GitHub username
   - Password: GitHub Personal Access Token (not your password!)
6. Click **"Connect"**
7. Should show "Connection Status: Successful" ✅

**Via CLI:**

```bash
# For public repo
argocd repo add https://github.com/yourusername/e-com-site

# For private repo
argocd repo add https://github.com/yourusername/e-com-site \
  --username <your-username> \
  --password <github-token>

# Verify
argocd repo list
```

---

### **Step 5: Create Your First Application (5 minutes)**

**Via UI:**

1. Click **"+ New App"** (top left)
2. **General:**
   - Application Name: `ecommerce-dev`
   - Project: `default`
   - Sync Policy: `Automatic`
   - Check ✅ "Prune Resources"
   - Check ✅ "Self Heal"
3. **Source:**
   - Repository URL: Select your repo
   - Revision: `main`
   - Path: `helm/ecommerce`
4. **Helm:**
   - Values Files: `values-dev.yaml`
5. **Destination:**
   - Cluster URL: `https://kubernetes.default.svc`
   - Namespace: `ecommerce`
6. Click **"Create"**

**Via YAML (Recommended for learning):**

```bash
# Create application manifest
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ecommerce-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourusername/e-com-site
    targetRevision: main
    path: helm/ecommerce
    helm:
      valueFiles:
      - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: ecommerce
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# Watch it deploy
kubectl get application ecommerce-dev -n argocd -w
```

---

### **Step 6: Watch ArgoCD Deploy (2 minutes)**

**In UI:**

1. Click on the **"ecommerce-dev"** application card
2. You'll see a beautiful visual tree of all resources
3. Watch them turn green as they deploy:
   - Deployments
   - Services
   - Pods
   - Ingress
   - PostgreSQL
   - Redis
   - RabbitMQ

**Status indicators:**

- 🟢 Green = Healthy and Synced
- 🟡 Yellow = Progressing
- 🔴 Red = Degraded/Failed
- ⚫ Gray = Unknown

**Via CLI:**

```bash
# Watch application status
argocd app get ecommerce-dev --watch

# Or check sync status
argocd app wait ecommerce-dev --timeout 600
```

---

### **Step 7: Verify Deployment**

```bash
# Check all resources deployed
kubectl get all -n ecommerce

# Get application status
argocd app get ecommerce-dev

# Should show:
# Health Status: Healthy ✅
# Sync Status:   Synced ✅

# Get ingress IP
kubectl get ingress -n ecommerce

# Test application
INGRESS_IP=$(kubectl get ingress -n ecommerce -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
curl http://$INGRESS_IP/api/products
```

---

### **Step 8: Test GitOps Workflow (5 minutes)**

**Make a change and watch ArgoCD deploy it:**

```bash
# 1. Edit your Helm values
cd helm/ecommerce
nano values-dev.yaml

# Change:
productService:
  replicaCount: 3  # Changed from 2

# 2. Commit and push
git add values-dev.yaml
git commit -m "Scale product-service to 3 replicas"
git push

# 3. Watch ArgoCD detect and deploy (within 3 minutes)
# - In UI: Watch the ecommerce-dev app
# - Status changes: Synced → OutOfSync → Syncing → Synced
# - See pods scale from 2 → 3

# 4. Verify
kubectl get pods -l app=product-service -n ecommerce
# Should show 3 pods!

# 🎉 You just did GitOps!
```

---

## ✅ **You're Now Running GitOps!**

**What you achieved:**

1. ✅ ArgoCD installed and running
2. ✅ Connected to your Git repository
3. ✅ Application deployed from Git
4. ✅ Automatic sync enabled
5. ✅ Made a change via Git and watched it auto-deploy

**Next steps:**

- Test rollback (git revert)
- Try manual change detection (kubectl scale)
- Explore the visual UI
- Set up notifications

---

## 🎓 **What is GitOps?**

**GitOps Principles:**

1. **Declarative** - Everything defined in Git (YAML)
2. **Versioned** - All changes tracked in Git history
3. **Pulled Automatically** - ArgoCD pulls from Git
4. **Continuously Reconciled** - Cluster always matches Git

**In simple terms:**

- Git = The truth
- ArgoCD = Makes cluster match Git
- You = Just commit to Git

---

## ❓ **What is ArgoCD?**

**ArgoCD** is a **declarative GitOps continuous delivery tool** for Kubernetes.

**Think of it as:**

- Your **Git repository** = Source of truth for cluster state
- **ArgoCD** = Automatically syncs Git → Kubernetes
- **You** = Just commit to Git, ArgoCD handles deployment

---

## 🤔 **Why Use ArgoCD?**

### **The Problem Without ArgoCD**

**Current workflow:**

```
1. Change code
2. Build Docker image
3. Push to ACR
4. Update Kubernetes manifest
5. Run kubectl apply or Helm upgrade
6. Hope it worked
7. If failed, manually fix
```

**Issues:**

- ❌ Manual deployment steps
- ❌ No audit trail (who deployed what?)
- ❌ No automatic rollback
- ❌ Different people deploy differently
- ❌ Cluster state can drift from Git
- ❌ No visibility into deployment status

---

### **With ArgoCD**

**New workflow:**

```
1. Change code
2. Build Docker image
3. Push to ACR
4. Commit updated manifest to Git
5. ArgoCD automatically deploys ✅
6. If failed, ArgoCD auto-rollbacks ✅
7. Full audit trail ✅
```

**Benefits:**

- ✅ **Git as single source of truth**
- ✅ **Automatic deployment** (commit → deploy)
- ✅ **Automatic sync** (cluster always matches Git)
- ✅ **Rollback via Git** (revert commit → auto-rollback)
- ✅ **Audit trail** (who changed what, when)
- ✅ **Drift detection** (alerts if manual changes made)
- ✅ **Multi-cluster** (deploy to multiple clusters from one Git repo)
- ✅ **Visual UI** (see deployment status)

---

## 📊 **Current vs GitOps Workflow**

### **Current: Push-Based Deployment**

```
Developer → Pipeline → kubectl apply → AKS Cluster
           (Azure DevOps)
```

**Who controls deployment:** Azure DevOps (external system)

---

### **With ArgoCD: Pull-Based GitOps**

```
Developer → Git commit → ArgoCD watches Git → Pulls changes → Applies to AKS
                         (inside cluster)
```

**Who controls deployment:** ArgoCD (inside cluster, watching Git)

---

## 🎯 **How ArgoCD Works**

### **The GitOps Loop**

```
┌─────────────────────────────────────────────────────┐
│  1. Developer commits to Git                        │
│     (Update image tag in Helm values)               │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  2. ArgoCD detects change                           │
│     (Polls Git every 3 minutes)                     │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  3. ArgoCD compares Git vs Cluster                  │
│     (Detects drift)                                 │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  4. ArgoCD syncs (applies changes)                  │
│     (Runs helm upgrade or kubectl apply)            │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  5. Cluster state matches Git ✅                    │
│     (Deployment complete)                           │
└─────────────────────────────────────────────────────┘
```

---

## 🚀 **Installing ArgoCD on Your AKS Cluster**

### **Step 1: Install ArgoCD**

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready (takes 2-3 minutes)
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

# Verify installation
kubectl get pods -n argocd

# Should show:
# argocd-server-xxx
# argocd-repo-server-xxx
# argocd-application-controller-xxx
# argocd-dex-server-xxx
# argocd-redis-xxx
```

**Time:** ~3-5 minutes

---

### **Step 2: Access ArgoCD UI**

**Option A: Port Forward (Quick)**

```bash
# Port forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open in browser: https://localhost:8080
# (Accept self-signed certificate warning)
```

**Option B: Expose via Ingress (Better)**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  rules:
    - host: argocd.yourdomain.com # Or use IP
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443
```

```bash
kubectl apply -f argocd-ingress.yaml

# Get IP
kubectl get ingress -n argocd

# Access: http://<INGRESS_IP>
```

---

### **Step 3: Get Initial Admin Password**

```bash
# Get the initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
echo

# Username: admin
# Password: <output from above>
```

**Login to UI:**

- URL: https://localhost:8080 (or your ingress IP)
- Username: `admin`
- Password: (from above)

---

### **Step 4: Change Admin Password**

```bash
# Install ArgoCD CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
argocd login localhost:8080

# Change password
argocd account update-password

# Delete initial secret
kubectl delete secret argocd-initial-admin-secret -n argocd
```

---

## 📦 **Connecting Your Git Repository**

### **Step 5: Add Your Git Repo to ArgoCD**

**Via UI:**

1. Settings → Repositories → Connect Repo
2. Choose: HTTPS or SSH
3. Enter repo URL: `https://github.com/yourusername/e-com-site`
4. Add credentials (if private)
5. Click "Connect"

**Via CLI:**

```bash
argocd repo add https://github.com/yourusername/e-com-site \
  --username <your-username> \
  --password <github-token>

# Or for public repos:
argocd repo add https://github.com/yourusername/e-com-site
```

**Via Declarative YAML:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ecommerce-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/yourusername/e-com-site
  username: <your-username>
  password: <github-token>
```

---

## 🎯 **Creating ArgoCD Applications**

### **Step 6: Create Application for Helm Chart**

**Via UI:**

1. Applications → New App
2. Application Name: `ecommerce-dev`
3. Project: `default`
4. Sync Policy: `Automatic`
5. Source:
   - Repository: Your repo URL
   - Path: `helm/ecommerce`
   - Helm Values: `values-dev.yaml`
6. Destination:
   - Cluster: `https://kubernetes.default.svc`
   - Namespace: `ecommerce`
7. Click "Create"

**Via CLI:**

```bash
argocd app create ecommerce-dev \
  --repo https://github.com/yourusername/e-com-site \
  --path helm/ecommerce \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace ecommerce \
  --values values-dev.yaml \
  --sync-policy automated \
  --self-heal \
  --auto-prune

# Sync the application
argocd app sync ecommerce-dev
```

**Via Declarative YAML (GitOps way!):**

```yaml
# argocd/applications/ecommerce-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ecommerce-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourusername/e-com-site
    targetRevision: main
    path: helm/ecommerce
    helm:
      valueFiles:
        - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: ecommerce
  syncPolicy:
    automated:
      prune: true # Delete resources removed from Git
      selfHeal: true # Auto-sync if manual changes detected
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

Apply it:

```bash
kubectl apply -f argocd/applications/ecommerce-dev.yaml
```

---

### **Step 7: Watch ArgoCD Deploy**

```bash
# Watch application sync
argocd app get ecommerce-dev --watch

# Or in UI:
# Click on "ecommerce-dev" application
# See visual deployment tree
# Watch resources turn green
```

---

## 🔄 **GitOps Workflow in Action**

### **Scenario 1: Deploy New Version**

```bash
# 1. Build new image (via pipeline)
# Image: acrecommercedev.azurecr.io/product-service:v1.2.0

# 2. Update Git
cd helm/ecommerce
# Edit values-dev.yaml:
# productService.image.tag: v1.2.0

git add values-dev.yaml
git commit -m "Deploy product-service v1.2.0"
git push

# 3. ArgoCD detects change (within 3 minutes)
# 4. ArgoCD automatically deploys v1.2.0
# 5. Done! ✅
```

**No kubectl, no helm upgrade needed!** Just commit to Git!

---

### **Scenario 2: Rollback**

```bash
# Something broke with v1.2.0

# Option A: Revert Git commit
git revert HEAD
git push

# ArgoCD automatically rolls back! ✅

# Option B: Rollback in ArgoCD UI
# Click application → History → Select previous version → Rollback
```

---

### **Scenario 3: Manual Change Detection**

```bash
# Someone manually changes replicas
kubectl scale deployment product-service --replicas=10 -n ecommerce

# ArgoCD detects drift!
# - Shows "OutOfSync" status
# - With selfHeal enabled, auto-reverts to Git state
# - Sends alert that manual change was made
```

---

## 📊 **ArgoCD vs Traditional CI/CD**

| Feature             | Azure DevOps Pipeline             | ArgoCD GitOps                |
| ------------------- | --------------------------------- | ---------------------------- |
| **Deployment**      | Push (pipeline pushes to cluster) | Pull (ArgoCD pulls from Git) |
| **Source of Truth** | Pipeline definition               | Git repository               |
| **Drift Detection** | ❌ No                             | ✅ Yes                       |
| **Auto Healing**    | ❌ No                             | ✅ Yes                       |
| **Rollback**        | Re-run old pipeline               | Revert Git commit            |
| **Audit Trail**     | Pipeline logs                     | Git commit history           |
| **Multi-Cluster**   | Complex                           | Easy                         |
| **Security**        | Pipeline needs cluster access     | Cluster pulls (more secure)  |
| **Declarative**     | Partially                         | Fully                        |
| **Visibility**      | Pipeline UI                       | Visual app tree              |

---

## 🏗️ **Your Architecture with ArgoCD**

### **Before ArgoCD:**

```
Developer → Git → Azure DevOps → kubectl/Helm → AKS Cluster
                  (build pipeline)  (deploy)
```

**Issues:**

- Pipeline needs cluster credentials
- Manual deployment steps
- No drift detection

---

### **With ArgoCD:**

```
Developer → Git commit
            ↓
            (ArgoCD watches Git)
            ↓
ArgoCD (in AKS) → Pulls from Git → Applies to AKS
```

**Benefits:**

- ✅ Cluster pulls changes (more secure)
- ✅ Automated deployment
- ✅ Drift detection and auto-healing

---

### **Hybrid Approach (Recommended):**

```
┌─────────────────────────────────────────────────┐
│ Azure DevOps Pipeline                           │
│ 1. Build Docker images                          │
│ 2. Push to ACR                                  │
│ 3. Update image tags in Git                     │
│ 4. Commit to Git                                │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ Git Repository (Source of Truth)                │
│ - Helm charts                                   │
│ - Kubernetes manifests                          │
│ - Image tags                                    │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ ArgoCD (Continuous Deployment)                  │
│ - Watches Git for changes                       │
│ - Automatically syncs to cluster                │
│ - Detects drift                                 │
│ - Auto-heals                                    │
└─────────────────────────────────────────────────┘
```

**This is the best practice!**

- Azure DevOps: Build and test
- ArgoCD: Deploy and manage

---

## 🎯 **For Your E-Commerce Project**

### **What ArgoCD Manages:**

```
argocd/
├── applications/
│   ├── ecommerce-dev.yaml       # Dev environment
│   ├── ecommerce-staging.yaml   # Staging
│   └── ecommerce-prod.yaml      # Production
└── app-of-apps.yaml             # Manages all apps
```

**ArgoCD automatically deploys:**

- ✅ All 3 microservices (product, user, frontend)
- ✅ Data layer (PostgreSQL, Redis, RabbitMQ)
- ✅ Ingress configuration
- ✅ Secrets (if in Git - use Sealed Secrets!)
- ✅ HPAs, Network Policies, etc.

---

## 📦 **ArgoCD Application Structure**

### **App-of-Apps Pattern**

Create one "parent" app that manages all your applications:

```yaml
# argocd/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ecommerce-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourusername/e-com-site
    targetRevision: main
    path: argocd/applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Then create individual apps:

```yaml
# argocd/applications/ecommerce-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ecommerce-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourusername/e-com-site
    targetRevision: main
    path: helm/ecommerce
    helm:
      valueFiles:
        - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: ecommerce
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Deploy the app-of-apps:**

```bash
kubectl apply -f argocd/app-of-apps.yaml

# ArgoCD will automatically create and manage all child apps!
```

---

## 🔐 **Managing Secrets with ArgoCD**

### **Problem:**

You can't commit secrets to Git! ❌

### **Solution: Sealed Secrets**

```bash
# 1. Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# 2. Install kubeseal CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-linux-amd64 -O kubeseal
chmod +x kubeseal
sudo mv kubeseal /usr/local/bin/

# 3. Create regular secret
kubectl create secret generic database-secrets \
  --from-literal=POSTGRES_PASSWORD=postgres123 \
  --dry-run=client -o yaml > secret.yaml

# 4. Seal it (encrypt)
kubeseal -f secret.yaml -w sealed-secret.yaml

# 5. Commit sealed-secret.yaml to Git (safe!)
git add sealed-secret.yaml
git commit -m "Add database secrets (encrypted)"
git push

# 6. ArgoCD deploys sealed secret
# 7. Sealed Secrets controller decrypts it in cluster
# 8. Your apps use the decrypted secret
```

**Result:** Secrets safely in Git, ArgoCD can deploy them! ✅

---

## 🔄 **GitOps Workflow Examples**

### **Example 1: Scale Replicas**

```bash
# 1. Edit values-dev.yaml
productService:
  replicaCount: 5  # Changed from 2

# 2. Commit
git add helm/ecommerce/values-dev.yaml
git commit -m "Scale product-service to 5 replicas"
git push

# 3. ArgoCD detects change (within 3 minutes)
# 4. ArgoCD scales deployment
# 5. Done! ✅

# Watch in ArgoCD UI - see pods scale from 2 → 5
```

---

### **Example 2: Deploy New Feature**

```bash
# 1. Code change in product-service

# 2. Azure DevOps pipeline builds image:
#    acrecommercedev.azurecr.io/product-service:v1.3.0

# 3. Pipeline updates Git:
git clone repo
sed -i 's|tag: v1.2.0|tag: v1.3.0|' helm/ecommerce/values-dev.yaml
git commit -m "Deploy product-service v1.3.0"
git push

# 4. ArgoCD auto-deploys v1.3.0
# 5. No manual kubectl needed! ✅
```

---

### **Example 3: Emergency Rollback**

```bash
# v1.3.0 has a bug!

# Option A: Revert Git commit
git revert HEAD
git push
# ArgoCD auto-rolls back to v1.2.0 ✅

# Option B: In ArgoCD UI
# Click app → History → Select v1.2.0 → Rollback
```

---

## 📊 **ArgoCD Features You'll Use**

### **1. Automatic Sync**

```yaml
syncPolicy:
  automated:
    prune: true # Delete resources removed from Git
    selfHeal: true # Undo manual changes
```

**Result:**

- Commit to Git → Auto-deploys (within 3 min)
- Manual kubectl change → Auto-reverted
- Deleted from Git → Auto-deleted from cluster

---

### **2. Health Checks**

ArgoCD shows health status:

- 🟢 **Healthy** - All resources ready
- 🟡 **Progressing** - Deployment in progress
- 🔴 **Degraded** - Some pods failed
- ⚫ **Missing** - Resource deleted

---

### **3. Sync Waves**

Control deployment order:

```yaml
# Deploy PostgreSQL first, then services
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0" # PostgreSQL (first)

---
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1" # Services (after DB)
---
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2" # Ingress (last)
```

---

### **4. Sync Windows**

Only allow deployments during specific times:

```yaml
syncPolicy:
  syncOptions:
    - RespectIgnoreDifferences=true
  syncWindow:
    - kind: allow
      schedule: "0 9 * * *" # Only sync at 9 AM
      duration: 1h
      applications:
        - ecommerce-prod
```

---

### **5. Notifications**

Get alerts on deployment status:

```bash
# Install ArgoCD notifications
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/release-1.0/manifests/install.yaml

# Configure Slack notifications
kubectl create secret generic argocd-notifications-secret \
  --from-literal=slack-token=<your-token> \
  -n argocd

# Configure triggers in argocd-cm ConfigMap
```

---

## 🎓 **Your Complete GitOps Setup**

### **Repository Structure:**

```
e-com-site/
├── services/                    # Source code
│   ├── product-service/
│   ├── user-service/
│   └── frontend-service/
├── helm/                        # Helm charts
│   └── ecommerce/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-staging.yaml
│       ├── values-prod.yaml
│       └── templates/
├── kubernetes/                  # Raw manifests (backup)
├── argocd/                      # ArgoCD configurations
│   ├── app-of-apps.yaml
│   └── applications/
│       ├── ecommerce-dev.yaml
│       ├── ecommerce-staging.yaml
│       └── ecommerce-prod.yaml
└── azure-pipelines/             # CI pipelines
    ├── build-and-push-pipeline.yml
    └── update-manifest-pipeline.yml  # Updates Git with new tags
```

---

### **Complete Workflow:**

```
1. Developer commits code
   ↓
2. Azure DevOps builds image (product-service:v1.3.0)
   ↓
3. Azure DevOps pushes to ACR
   ↓
4. Azure DevOps updates values-dev.yaml in Git
   (productService.image.tag: v1.3.0)
   ↓
5. ArgoCD detects Git change
   ↓
6. ArgoCD syncs cluster
   ↓
7. New version deployed! ✅
   ↓
8. ArgoCD monitors health
   ↓
9. If unhealthy, alerts sent
```

---

## 🚀 **Quick Start for Your Project**

### **Complete Setup (15 minutes)**

```bash
# 1. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

# 2. Get password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# 3. Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# 4. Login to UI (https://localhost:8080)
# Username: admin, Password: <from step 2>

# 5. Add your Git repo (in UI or CLI)

# 6. Create application (use YAML from Step 6 above)
kubectl apply -f argocd/applications/ecommerce-dev.yaml

# 7. Watch it deploy
# Open ArgoCD UI, see visual deployment tree!

# Done! ✅
```

---

## 📋 **ArgoCD CLI Commands**

```bash
# Login
argocd login localhost:8080

# List apps
argocd app list

# Get app details
argocd app get ecommerce-dev

# Sync app
argocd app sync ecommerce-dev

# View diff
argocd app diff ecommerce-dev

# Rollback
argocd app rollback ecommerce-dev <revision>

# Delete app
argocd app delete ecommerce-dev

# View history
argocd app history ecommerce-dev

# Set auto-sync
argocd app set ecommerce-dev --sync-policy automated

# Disable auto-sync
argocd app set ecommerce-dev --sync-policy none
```

---

## 🎯 **Best Practices**

### **1. Use App-of-Apps Pattern**

Manage multiple apps with one parent app.

### **2. Environment Separation**

```
Git branches:
- main → Production
- staging → Staging
- develop → Development

Or:
- main branch with different value files
- ArgoCD apps point to different values
```

### **3. Sealed Secrets**

Never commit plain secrets to Git!

### **4. Sync Waves**

Order deployment (DB first, then apps, then ingress).

### **5. Health Checks**

Let ArgoCD validate deployment success.

### **6. Notifications**

Get alerts on Slack/Email when deployments fail.

---

## 💡 **ArgoCD + Azure DevOps Pipeline**

### **Updated Pipeline:**

```yaml
# azure-pipelines/gitops-pipeline.yml
stages:
  - stage: Build
    jobs:
      - job: BuildImages
        steps:
          -  # Build and push images (existing)

  - stage: UpdateGit
    jobs:
      - job: UpdateManifests
        steps:
          - bash: |
              # Update image tags in Git
              cd helm/ecommerce
              sed -i 's|tag: .*|tag: $(Build.BuildNumber)|' values-dev.yaml

              # Commit and push
              git config user.email "pipeline@azuredevops.com"
              git config user.name "Azure Pipeline"
              git add values-dev.yaml
              git commit -m "Deploy build $(Build.BuildNumber)"
              git push
            displayName: "Update Git with new image tags"

  # No deploy stage needed - ArgoCD handles it!
```

**Workflow:**

1. Pipeline builds image
2. Pipeline updates Git
3. ArgoCD deploys
4. Done!

---

## 🔍 **Monitoring with ArgoCD**

### **Application Health**

```bash
# Check application health
argocd app get ecommerce-dev

# Shows:
# Health Status: Healthy
# Sync Status:   Synced
```

---

### **Resource Tree**

In UI, see visual tree:

```
ecommerce-dev
├── Deployment: product-service (Healthy)
│   └── ReplicaSet (Healthy)
│       └── Pod: product-service-xxx (Running)
├── Service: product-service (Healthy)
├── HPA: product-service-hpa (Healthy)
├── Deployment: user-service (Healthy)
└── Ingress: ecommerce-ingress (Healthy)
```

---

### **Sync Status**

- **Synced** - Cluster matches Git ✅
- **OutOfSync** - Cluster differs from Git ⚠️
- **Unknown** - Can't determine

---

## 🐛 **Troubleshooting**

### **App Shows OutOfSync**

```bash
# See what's different
argocd app diff ecommerce-dev

# Manually sync
argocd app sync ecommerce-dev

# Force hard refresh
argocd app sync ecommerce-dev --force
```

---

### **Sync Fails**

```bash
# Check sync errors
argocd app get ecommerce-dev

# Check logs
kubectl logs -n argocd deployment/argocd-application-controller

# Try manual sync with prune
argocd app sync ecommerce-dev --prune
```

---

### **ArgoCD Can't Access Git**

```bash
# Check repo connection
argocd repo list

# Test repo
argocd repo get https://github.com/yourusername/e-com-site

# Re-add repo with credentials
argocd repo add https://github.com/yourusername/e-com-site \
  --username <user> \
  --password <token>
```

---

## 💰 **Cost**

**ArgoCD itself:** Free (open-source) ✅

**Resource usage:**

- Control plane: ~500MB RAM, ~0.5 CPU
- For your cluster: Negligible impact

---

## ✅ **Benefits for Your Learning Project**

### **What You Learn:**

1. ✅ **GitOps principles** - Industry best practice
2. ✅ **Declarative deployment** - Everything in Git
3. ✅ **Drift detection** - Cluster state vs Git
4. ✅ **Automated workflows** - Commit → Deploy
5. ✅ **Visual monitoring** - See deployment trees
6. ✅ **Rollback strategies** - Via Git history
7. ✅ **Multi-environment** - Dev, staging, prod
8. ✅ **Resume skills** - "Implemented GitOps with ArgoCD"

---

## 🎓 **Learning Path**

### **Week 1: Basic ArgoCD**

- Install ArgoCD
- Create application pointing to your Helm chart
- Deploy via ArgoCD
- Understand sync process

### **Week 2: GitOps Workflow**

- Update image tag in Git
- Watch ArgoCD auto-deploy
- Test rollback via Git revert
- Configure auto-sync and self-heal

### **Week 3: Advanced**

- Implement Sealed Secrets
- Use app-of-apps pattern
- Configure sync waves
- Set up notifications

### **Week 4: Integration**

- Integrate with Azure DevOps
- Pipeline updates Git
- ArgoCD deploys
- Full CI/CD GitOps workflow

---

## 📊 **Comparison**

| Method           | Setup Time | Deployment | Rollback        | Drift Detection | Audit Trail   |
| ---------------- | ---------- | ---------- | --------------- | --------------- | ------------- |
| **kubectl**      | 0 min      | Manual     | Manual          | ❌ No           | ❌ No         |
| **Helm**         | 5 min      | Manual     | helm rollback   | ❌ No           | Helm history  |
| **Azure DevOps** | 30 min     | Automated  | Re-run pipeline | ❌ No           | Pipeline logs |
| **ArgoCD**       | 15 min     | Automated  | Git revert      | ✅ Yes          | Git commits   |

---

## 🎯 **Recommendation for You**

**Implement ArgoCD because:**

1. ✅ **Learn GitOps** - Industry standard
2. ✅ **Resume value** - Shows advanced K8s knowledge
3. ✅ **Easy setup** - 15 minutes
4. ✅ **Great for learning** - Visual feedback
5. ✅ **Real-world practice** - Used in production everywhere

**Workflow:**

- Keep Azure DevOps for **CI** (build, test, push images)
- Use ArgoCD for **CD** (continuous deployment)

---

## 🚀 **Quick Install Script**

```bash
#!/bin/bash
# install-argocd.sh

echo "Installing ArgoCD..."

# Install
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

# Get password
echo ""
echo "ArgoCD installed!"
echo "Username: admin"
echo "Password:"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "Access ArgoCD:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then open: https://localhost:8080"
```

---

## 📚 **Additional Resources**

- **ArgoCD Docs:** https://argo-cd.readthedocs.io/
- **GitOps Guide:** https://www.gitops.tech/
- **Best Practices:** https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/
- **Sealed Secrets:** https://github.com/bitnami-labs/sealed-secrets

---

## ✅ **Summary**

**ArgoCD = GitOps for Kubernetes**

**What it does:**

- Watches Git repository
- Automatically deploys changes
- Detects and fixes drift
- Provides visual UI
- Manages rollbacks

**For your project:**

- ✅ Add ArgoCD (15 min setup)
- ✅ Keep Azure DevOps for building images
- ✅ Use ArgoCD for deploying to K8s
- ✅ Get full GitOps workflow
- ✅ Learn industry best practice

**Install ArgoCD and your deployment becomes: Just commit to Git!** 🎉
