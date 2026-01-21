# Security & Best Practices for AKS Learning Project

Comprehensive guide to security enhancements and best practices you can implement on your e-commerce microservices cluster.

---

## 📋 **Table of Contents**

1. [Security](#security)
2. [Secrets Management](#secrets-management)
3. [Network Policies](#network-policies)
4. [Pod Security](#pod-security)
5. [RBAC (Role-Based Access Control)](#rbac)
6. [Image Security](#image-security)
7. [Monitoring & Logging](#monitoring--logging)
8. [High Availability](#high-availability)
9. [Disaster Recovery](#disaster-recovery)
10. [Cost Optimization](#cost-optimization)

---

## 🔐 **1. Security**

### **A. Implement Network Policies**

**What it does:** Control which pods can talk to which pods (firewall for Kubernetes).

**Current state:** Any pod can call any pod ❌  
**Best practice:** Only allow necessary communication ✅

**Implementation:**

```bash
# Create network-policies.yaml
cat <<EOF | kubectl apply -f -
# Allow only frontend to call product-service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: product-service-policy
  namespace: ecommerce
spec:
  podSelector:
    matchLabels:
      app: product-service
  policyTypes:
  - Ingress
  ingress:
  # Allow from frontend
  - from:
    - podSelector:
        matchLabels:
          app: frontend-service
    ports:
    - protocol: TCP
      port: 8081
  # Allow from ingress
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8081

---
# Allow only frontend and product-service to call user-service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: user-service-policy
  namespace: ecommerce
spec:
  podSelector:
    matchLabels:
      app: user-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend-service
    - podSelector:
        matchLabels:
          app: product-service
    ports:
    - protocol: TCP
      port: 8080

---
# PostgreSQL - only allow product and user services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-policy
  namespace: ecommerce
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: product-service
    - podSelector:
        matchLabels:
          app: user-service
    ports:
    - protocol: TCP
      port: 5432
EOF

# Verify
kubectl get networkpolicies -n ecommerce
```

**Test it:**

```bash
# Try to call product-service from a random pod (should fail)
kubectl run test-pod --rm -it --image=curlimages/curl -n ecommerce -- sh
# curl http://product-service:8081/api/products
# Should timeout or be rejected
```

---

### **B. Pod Security Standards**

**What it does:** Enforce security constraints on pods.

**Implementation:**

```bash
# Label namespace with Pod Security Standard
kubectl label namespace ecommerce \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted

# This enforces:
# - No privileged containers
# - No host network/ports
# - Must run as non-root
# - Read-only root filesystem (where possible)
```

**Update your deployments to comply:**

```yaml
# In deployment.yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: product-service
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
```

---

### **C. Enable Azure Defender for Containers**

**What it does:** Scans for vulnerabilities and threats.

```bash
# Enable via Azure CLI
az aks update \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev \
  --enable-defender

# Cost: ~$7/node/month
```

**What you get:**

- ✅ Vulnerability scanning
- ✅ Runtime threat detection
- ✅ Security recommendations
- ✅ Compliance dashboard

---

## 🔑 **2. Secrets Management**

### **A. Use Azure Key Vault (Production Best Practice)**

**Current:** Secrets stored in Kubernetes ❌  
**Better:** Secrets in Azure Key Vault ✅

**Implementation:**

```bash
# 1. Create Key Vault
az keyvault create \
  --name kv-ecommerce-dev \
  --resource-group rg-ecommerce-aks-dev \
  --location eastus

# 2. Add secrets
az keyvault secret set --vault-name kv-ecommerce-dev --name postgres-password --value "your-secure-password"
az keyvault secret set --vault-name kv-ecommerce-dev --name jwt-secret --value "your-jwt-secret"

# 3. Install CSI driver
helm repo add csi-secrets-store-provider-azure https://azure.github.io/secrets-store-csi-driver-provider-azure/charts
helm install csi csi-secrets-store-provider-azure/csi-secrets-store-provider-azure

# 4. Create SecretProviderClass
cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-sync
  namespace: ecommerce
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: <MANAGED_IDENTITY_CLIENT_ID>
    keyvaultName: kv-ecommerce-dev
    objects: |
      array:
        - |
          objectName: postgres-password
          objectType: secret
        - |
          objectName: jwt-secret
          objectType: secret
    tenantId: <YOUR_TENANT_ID>
  secretObjects:
  - secretName: database-secrets
    type: Opaque
    data:
    - objectName: postgres-password
      key: POSTGRES_PASSWORD
EOF

# 5. Mount in deployment
# Add to deployment.yaml:
volumes:
- name: secrets-store
  csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: azure-kv-sync
volumeMounts:
- name: secrets-store
  mountPath: "/mnt/secrets-store"
  readOnly: true
```

**Benefits:**

- ✅ Centralized secret management
- ✅ Automatic rotation
- ✅ Audit logging
- ✅ RBAC on secrets

---

### **B. Encrypt Secrets at Rest**

```bash
# Enable encryption at rest in AKS
az aks update \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev \
  --enable-encryption-at-host

# Secrets in etcd are encrypted
```

---

### **C. Sealed Secrets (GitOps-friendly)**

**What it does:** Encrypt secrets so they can be stored in Git safely.

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-linux-amd64 -O kubeseal
chmod +x kubeseal
sudo mv kubeseal /usr/local/bin/

# Create a sealed secret
kubectl create secret generic my-secret \
  --from-literal=password=supersecret \
  --dry-run=client -o yaml | kubeseal -o yaml > sealed-secret.yaml

# Now you can commit sealed-secret.yaml to git safely!
kubectl apply -f sealed-secret.yaml
```

---

## 🌐 **3. Network Policies**

### **Default Deny All**

Start with denying everything, then allow specific traffic:

```yaml
# Deny all ingress traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: ecommerce
spec:
  podSelector: {}
  policyTypes:
    - Ingress

---
# Deny all egress traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: ecommerce
spec:
  podSelector: {}
  policyTypes:
    - Egress
```

**Then allow specific traffic** (examples in Section 1A above).

---

### **Restrict Egress Traffic**

Prevent pods from calling external services:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: product-service-egress
  namespace: ecommerce
spec:
  podSelector:
    matchLabels:
      app: product-service
  policyTypes:
    - Egress
  egress:
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
    # Allow PostgreSQL
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
  # Block everything else
```

---

## 🛡️ **4. Pod Security**

### **A. Run as Non-Root User**

Update all your deployments:

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: product-service
          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            runAsUser: 1000
            capabilities:
              drop:
                - ALL
```

**Update Dockerfiles:**

```dockerfile
# Add to your Python service Dockerfiles
RUN addgroup --gid 1000 appuser && \
    adduser --uid 1000 --gid 1000 --disabled-password appuser

USER appuser
```

---

### **B. Read-Only Root Filesystem**

```yaml
containers:
  - name: product-service
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
      - name: tmp
        mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

---

### **C. Resource Limits (Prevent DOS)**

Already in your manifests, but ensure all have:

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "1000m"
```

**Best practice:**

- Set requests = guaranteed resources
- Set limits = maximum allowed
- Prevents one pod from consuming all cluster resources

---

## 👤 **5. RBAC (Role-Based Access Control)**

### **A. Create Service Accounts**

```bash
# Create service accounts for each service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: product-service-sa
  namespace: ecommerce
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: user-service-sa
  namespace: ecommerce
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: frontend-service-sa
  namespace: ecommerce
EOF

# Update deployments to use service accounts
# Add to deployment.yaml:
spec:
  template:
    spec:
      serviceAccountName: product-service-sa
```

---

### **B. Limit Permissions**

```bash
# Create Role with minimal permissions
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: product-service-role
  namespace: ecommerce
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["database-secrets"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: product-service-rolebinding
  namespace: ecommerce
subjects:
- kind: ServiceAccount
  name: product-service-sa
  namespace: ecommerce
roleRef:
  kind: Role
  name: product-service-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

---

### **C. Disable Default Service Account**

```bash
# Prevent pods from using default SA with full permissions
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
  namespace: ecommerce
automountServiceAccountToken: false
EOF
```

---

## 🖼️ **6. Image Security**

### **A. Image Scanning**

**Scan images for vulnerabilities:**

```bash
# Using Trivy (free)
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan your images
trivy image acrecommercedev.azurecr.io/product-service:latest
trivy image acrecommercedev.azurecr.io/user-service:latest
trivy image acrecommercedev.azurecr.io/frontend-service:latest

# Fix HIGH and CRITICAL vulnerabilities

# Using Azure Defender
az acr task create \
  --registry acrecommercedev \
  --name scan-images \
  --context /dev/null \
  --cmd "az acr scan --registry acrecommercedev"
```

---

### **B. Image Pull Policies**

```yaml
# In deployment.yaml
spec:
  containers:
    - name: product-service
      image: acrecommercedev.azurecr.io/product-service:v1.0.0
      imagePullPolicy: Always # Always pull latest (security patches)
```

**Best practices:**

- ✅ Use specific tags (`:v1.0.0`) not `:latest`
- ✅ Use `imagePullPolicy: Always` for security patches
- ✅ Sign images (Docker Content Trust)

---

### **C. Private Container Registry**

**Already done!** ✅ Using ACR (private registry)

**Additional:** Enable Content Trust

```bash
# Enable content trust in ACR
az acr config content-trust update \
  --name acrecommercedev \
  --status enabled
```

---

### **D. Minimal Base Images**

**Update Dockerfiles to use minimal images:**

```dockerfile
# Instead of:
FROM python:3.11

# Use:
FROM python:3.11-slim  # 50% smaller

# Or even better (advanced):
FROM gcr.io/distroless/python3  # Only app and runtime, no shell
```

**Benefits:**

- ✅ Smaller attack surface
- ✅ Faster pulls
- ✅ Lower cost

---

## 📊 **7. Monitoring & Logging**

### **A. Centralized Logging (ELK/Loki)**

**Install Loki for log aggregation:**

```bash
# Install Loki stack
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --create-namespace \
  --set promtail.enabled=true \
  --set grafana.enabled=true

# Access Grafana
kubectl port-forward -n monitoring svc/loki-grafana 3000:80

# Login: admin / <get password>
kubectl get secret loki-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d
```

**Query logs:**

```
{namespace="ecommerce", app="product-service"}
```

---

### **B. Prometheus + Grafana for Metrics**

**Already have it with Istio!** If not using Istio:

```bash
# Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Import dashboards:
# - Kubernetes Cluster Monitoring (ID: 7249)
# - Kubernetes Pods Monitoring (ID: 6417)
```

---

### **C. Application Insights Integration**

**Azure-native monitoring:**

```bash
# Install Application Insights agent
az aks enable-addons \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev \
  --addons monitoring \
  --workspace-resource-id <LOG_ANALYTICS_WORKSPACE_ID>
```

**Add to your Python apps:**

```python
# In requirements.txt
opencensus-ext-azure

# In app/main.py
from opencensus.ext.azure import metrics_exporter
from opencensus.stats import stats as stats_module

exporter = metrics_exporter.new_metrics_exporter(
    connection_string='InstrumentationKey=<YOUR_KEY>'
)
stats_module.stats.view_manager.register_exporter(exporter)
```

---

### **D. Alerts and Notifications**

```yaml
# Prometheus Alert Rules
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alerts
  namespace: monitoring
data:
  alerts.yml: |
    groups:
    - name: ecommerce
      rules:
      # High error rate
      - alert: HighErrorRate
        expr: sum(rate(http_requests_total{status=~"5.."}[5m])) > 10
        for: 5m
        annotations:
          summary: "High error rate in ecommerce services"
      
      # Pod down
      - alert: PodDown
        expr: up{namespace="ecommerce"} == 0
        for: 2m
        annotations:
          summary: "Pod is down in ecommerce namespace"
      
      # High memory usage
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes{namespace="ecommerce"} / container_spec_memory_limit_bytes > 0.9
        for: 5m
        annotations:
          summary: "Container using >90% memory"
```

---

## 🔄 **8. High Availability**

### **A. Pod Disruption Budgets**

**Ensure minimum pods available during updates:**

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: product-service-pdb
  namespace: ecommerce
spec:
  minAvailable: 1 # At least 1 pod must be available
  selector:
    matchLabels:
      app: product-service

---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: user-service-pdb
  namespace: ecommerce
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: user-service
```

**Prevents:**

- ❌ All pods being terminated during node maintenance
- ❌ Downtime during upgrades

---

### **B. Anti-Affinity Rules**

**Spread pods across nodes:**

```yaml
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - product-service
                topologyKey: kubernetes.io/hostname
```

**Result:** Each pod runs on a different node (if possible).

---

### **C. Health Checks (Already Implemented!)**

You already have:

- ✅ Liveness probes
- ✅ Readiness probes

**Enhance with startup probes:**

```yaml
containers:
  - name: product-service
    startupProbe:
      httpGet:
        path: /health
        port: 8081
      failureThreshold: 30
      periodSeconds: 10
    # Gives app 5 minutes to start (30 × 10s)
```

---

## 💾 **9. Disaster Recovery**

### **A. Backup Strategy**

**Backup Persistent Volumes:**

```bash
# Install Velero for cluster backups
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set-file credentials.secretContents.cloud=./credentials-azure \
  --set configuration.provider=azure \
  --set configuration.backupStorageLocation.bucket=velero-backups \
  --set configuration.backupStorageLocation.config.resourceGroup=rg-ecommerce-aks-dev \
  --set configuration.backupStorageLocation.config.storageAccount=velerostorage \
  --set snapshotsEnabled=true

# Create backup
velero backup create ecommerce-backup --include-namespaces ecommerce

# Restore from backup
velero restore create --from-backup ecommerce-backup
```

---

### **B. Database Backups**

**PostgreSQL automated backups:**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: ecommerce
spec:
  schedule: "0 2 * * *" # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: postgres:15
              env:
                - name: PGPASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: database-secrets
                      key: POSTGRES_PASSWORD
              command:
                - /bin/sh
                - -c
                - |
                  pg_dump -h postgres-service -U postgres products_db | gzip > /backup/products_db_$(date +%Y%m%d_%H%M%S).sql.gz
                  pg_dump -h postgres-service -U postgres users_db | gzip > /backup/users_db_$(date +%Y%m%d_%H%M%S).sql.gz
              volumeMounts:
                - name: backup-storage
                  mountPath: /backup
          restartPolicy: OnFailure
          volumes:
            - name: backup-storage
              persistentVolumeClaim:
                claimName: postgres-backup-pvc
```

---

### **C. Configuration Backup**

```bash
# Export all Kubernetes resources
kubectl get all,configmap,secret,pvc,ingress -n ecommerce -o yaml > ecommerce-backup.yaml

# Store in git or Azure Blob Storage
az storage blob upload \
  --account-name <storage> \
  --container backups \
  --file ecommerce-backup.yaml \
  --name ecommerce-backup-$(date +%Y%m%d).yaml
```

---

## 💰 **10. Cost Optimization**

### **A. Vertical Pod Autoscaler (VPA)**

**Right-size your pods automatically:**

```bash
# Install VPA
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler
./hack/vpa-up.sh

# Create VPA for product-service
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: product-service-vpa
  namespace: ecommerce
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: product-service
  updatePolicy:
    updateMode: "Auto"  # Automatically update resource requests
EOF

# VPA will recommend and apply optimal CPU/memory settings
kubectl get vpa -n ecommerce
```

---

### **B. Cluster Autoscaler**

**Scale nodes based on demand:**

```bash
# Enable cluster autoscaler
az aks update \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-ecommerce-dev \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 5

# Cluster will:
# - Scale down to 1 node when idle (save money)
# - Scale up to 5 nodes under load
```

---

### **C. Spot Instances for Non-Critical Workloads**

```bash
# Add spot node pool (up to 90% cheaper!)
az aks nodepool add \
  --resource-group rg-ecommerce-aks-dev \
  --cluster-name aks-ecommerce-dev \
  --name spotpool \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1 \
  --node-count 1 \
  --min-count 1 \
  --max-count 3 \
  --node-taints kubernetes.azure.com/scalesetpriority=spot:NoSchedule

# Deploy non-critical workloads to spot nodes
# Add to deployment:
spec:
  template:
    spec:
      tolerations:
      - key: "kubernetes.azure.com/scalesetpriority"
        operator: "Equal"
        value: "spot"
        effect: "NoSchedule"
```

---

### **D. Resource Quotas**

**Prevent resource exhaustion:**

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ecommerce-quota
  namespace: ecommerce
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
    services: "10"
```

---

## 🔧 **11. Additional Best Practices**

### **A. ConfigMaps for Configuration**

**Externalize configuration:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: product-service-config
  namespace: ecommerce
data:
  LOG_LEVEL: "INFO"
  MAX_CONNECTIONS: "100"
  CACHE_TTL: "300"
```

**Use in deployment:**

```yaml
containers:
  - name: product-service
    envFrom:
      - configMapRef:
          name: product-service-config
```

---

### **B. Liveness and Readiness Probes**

**You already have these!** ✅ But enhance them:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8081
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
  successThreshold: 1

readinessProbe:
  httpGet:
    path: /ready # Different endpoint
    port: 8081
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

**Add to your FastAPI apps:**

```python
@app.get("/ready")
async def readiness():
    # Check dependencies
    try:
        await db.execute("SELECT 1")
        return {"status": "ready"}
    except:
        raise HTTPException(status_code=503, detail="Not ready")
```

---

### **C. Graceful Shutdown**

**Handle SIGTERM properly:**

```python
# In your FastAPI app
import signal
import sys

def signal_handler(sig, frame):
    print('Graceful shutdown initiated...')
    # Close database connections
    # Finish processing requests
    sys.exit(0)

signal.signal(signal.SIGTERM, signal_handler)
```

**In deployment:**

```yaml
containers:
  - name: product-service
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 15"]
```

---

### **D. Resource Requests = Limits (Guaranteed QoS)**

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "256Mi" # Same as requests
    cpu: "200m" # Same as requests
```

**Result:** Guaranteed QoS class (best performance).

---

## 🔍 **12. Security Scanning & Compliance**

### **A. Kubescape**

**Scan cluster for security issues:**

```bash
# Install Kubescape
curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash

# Scan your cluster
kubescape scan framework nsa --exclude-namespaces kube-system,kube-public

# Scan specific namespace
kubescape scan framework nsa --include-namespaces ecommerce

# Get a security score
```

---

### **B. Kube-bench**

**Check CIS Kubernetes Benchmark compliance:**

```bash
# Run as a job
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job-aks.yaml

# View results
kubectl logs -f job/kube-bench-aks -n default
```

---

### **C. Falco (Runtime Security)**

**Detect anomalous behavior at runtime:**

```bash
# Install Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace

# Monitor alerts
kubectl logs -f -n falco -l app.kubernetes.io/name=falco

# Example alerts:
# - Shell spawned in container
# - File opened for writing under /etc
# - Unauthorized process started
```

---

## 🌟 **13. Advanced Features**

### **A. Mutual TLS (mTLS) Without Service Mesh**

**Using cert-manager:**

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create CA
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ca-certificate
  namespace: cert-manager
spec:
  isCA: true
  commonName: ecommerce-ca
  secretName: ca-secret
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
EOF

# Use in services for mTLS
```

---

### **B. External Secrets Operator**

**Sync secrets from external sources:**

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace

# Sync from Azure Key Vault
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-secret-store
  namespace: ecommerce
spec:
  provider:
    azurekv:
      authType: ManagedIdentity
      vaultUrl: "https://kv-ecommerce-dev.vault.azure.net"

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-secrets-external
  namespace: ecommerce
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-secret-store
    kind: SecretStore
  target:
    name: database-secrets
  data:
  - secretKey: POSTGRES_PASSWORD
    remoteRef:
      key: postgres-password
EOF
```

---

### **C. Admission Controllers**

**Enforce policies at deployment time:**

```bash
# Install OPA Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml

# Create policy: All images must come from ACR
cat <<EOF | kubectl apply -f -
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: allowedrepos
spec:
  crd:
    spec:
      names:
        kind: AllowedRepos
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package allowedrepos
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not startswith(container.image, "acrecommercedev.azurecr.io/")
          msg := sprintf("Image '%v' is not from allowed registry", [container.image])
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: AllowedRepos
metadata:
  name: acr-only
spec:
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    namespaces: ["ecommerce"]
EOF

# Try to deploy image from Docker Hub - will be rejected!
```

---

## 📋 **14. Implementation Checklist**

### **Security (Priority: HIGH)**

- [ ] Network policies implemented
- [ ] Pod security standards enforced
- [ ] Running as non-root user
- [ ] Secrets in Azure Key Vault
- [ ] Image scanning enabled
- [ ] RBAC configured
- [ ] mTLS enabled (Istio or manual)

### **Monitoring (Priority: HIGH)**

- [ ] Prometheus + Grafana installed
- [ ] Centralized logging (Loki)
- [ ] Distributed tracing (Jaeger)
- [ ] Alerts configured
- [ ] Dashboards created

### **High Availability (Priority: MEDIUM)**

- [ ] Pod Disruption Budgets
- [ ] Anti-affinity rules
- [ ] Health checks configured
- [ ] Multiple replicas

### **Disaster Recovery (Priority: MEDIUM)**

- [ ] Velero backups configured
- [ ] Database backup CronJob
- [ ] Configuration backed up
- [ ] Recovery procedure documented

### **Cost Optimization (Priority: LOW for learning)**

- [ ] VPA enabled
- [ ] Cluster autoscaler configured
- [ ] Resource quotas set
- [ ] Spot instances for dev workloads

---

## 🎓 **Learning Path**

### **Week 1: Security Basics**

1. Implement network policies
2. Add pod security contexts
3. Configure RBAC
4. Scan images with Trivy

### **Week 2: Observability**

1. Install Prometheus + Grafana
2. Install Loki for logging
3. Set up alerts
4. Create dashboards

### **Week 3: Service Mesh**

1. Install Istio or Linkerd
2. Enable mTLS
3. Configure traffic management
4. Test canary deployments

### **Week 4: Advanced**

1. Implement admission controllers
2. Set up Velero backups
3. Configure external secrets
4. Test disaster recovery

---

## 💡 **Quick Wins (Implement These First)**

### **1. Network Policies** (30 minutes)

- Immediate security improvement
- Prevent unauthorized access
- Easy to implement

### **2. Pod Security Context** (15 minutes)

- Run as non-root
- Drop all capabilities
- Quick security win

### **3. Image Scanning** (15 minutes)

- Install Trivy
- Scan your images
- Fix vulnerabilities

### **4. Resource Limits** (Already done!) ✅

- You already have these
- Prevents resource exhaustion

### **5. RBAC** (30 minutes)

- Create service accounts
- Limit permissions
- Security best practice

---

## 🚀 **Next Steps for Your Project**

**Immediate (This Week):**

1. ✅ Implement network policies
2. ✅ Scan images with Trivy
3. ✅ Add pod security contexts

**Short-term (Next 2 Weeks):**

1. ✅ Install Linkerd (easier than Istio for learning)
2. ✅ Set up Prometheus + Grafana
3. ✅ Configure RBAC

**Long-term (Month 2):**

1. ✅ Migrate to Istio
2. ✅ Implement Azure Key Vault integration
3. ✅ Set up automated backups

---

## 📚 **Additional Resources**

- **Security:** https://kubernetes.io/docs/concepts/security/
- **Best Practices:** https://learnk8s.io/production-best-practices
- **AKS Security:** https://docs.microsoft.com/en-us/azure/aks/concepts-security
- **CIS Benchmark:** https://www.cisecurity.org/benchmark/kubernetes

---

## ✅ **Summary**

You can implement:

**Security:**

- Network policies
- Pod security standards
- RBAC
- Secrets in Key Vault
- Image scanning
- mTLS (via Istio/Linkerd)

**Observability:**

- Prometheus + Grafana
- Centralized logging (Loki)
- Distributed tracing (Jaeger)
- Custom dashboards

**Reliability:**

- Pod disruption budgets
- Anti-affinity rules
- Circuit breakers
- Retries and timeouts

**Operations:**

- Automated backups
- Disaster recovery
- GitOps (ArgoCD)
- Policy enforcement

**All of these are valuable learning experiences and look great on your resume!** 🌟

Start with the "Quick Wins" section - you'll have significant improvements in under 2 hours! 🚀
