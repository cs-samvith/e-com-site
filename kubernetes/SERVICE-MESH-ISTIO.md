# Istio Installation and Configuration Guide for AKS

Complete step-by-step guide to install and configure Istio service mesh on your AKS e-commerce cluster.

---

## 📋 **Prerequisites**

- ✅ AKS cluster running (aks-ecommerce-dev)
- ✅ kubectl configured and connected
- ✅ At least 2 nodes with 8GB RAM each
- ✅ Your 3 microservices deployed (product, user, frontend)

---

## 🚀 **Part 1: Install Istio**

### **Step 1: Download Istio**

```bash
# Download latest Istio (1.20.x)
curl -L https://istio.io/downloadIstio | sh -

# Move to Istio directory
cd istio-1.20.*

# Add istioctl to PATH
export PATH=$PWD/bin:$PATH

# Verify installation
istioctl version

# Should show: no ready Istio pods in "istio-system"
```

---

### **Step 2: Pre-installation Check**

```bash
# Validate cluster is ready for Istio
istioctl x precheck

# Should show all green checkmarks:
# ✓ Kubernetes version
# ✓ Istio APIs available
# ✓ No conflicting installations
```

**If you see errors:**

- Check Kubernetes version: `kubectl version`
- Ensure cluster has enough resources: `kubectl top nodes`

---

### **Step 3: Install Istio**

```bash
# Install Istio with demo profile (good for learning)
istioctl install --set profile=demo -y

# This installs:
# - istiod (control plane)
# - istio-ingressgateway (replaces NGINX)
# - istio-egressgateway (for outbound traffic)

# Wait for installation (takes 2-3 minutes)
```

**Output should show:**

```
✔ Istio core installed
✔ Istiod installed
✔ Ingress gateways installed
✔ Egress gateways installed
✔ Installation complete
```

---

### **Step 4: Verify Installation**

```bash
# Check Istio components are running
kubectl get pods -n istio-system

# Should show (all Running):
# istiod-xxx                1/1     Running
# istio-ingressgateway-xxx  1/1     Running
# istio-egressgateway-xxx   1/1     Running

# Check Istio version
istioctl version

# Should show both client and control plane versions
```

---

### **Step 5: Install Istio Addons (Observability)**

```bash
# Install Prometheus, Grafana, Kiali, Jaeger
kubectl apply -f samples/addons

# Wait for pods to start
kubectl rollout status deployment/kiali -n istio-system
kubectl rollout status deployment/prometheus -n istio-system
kubectl rollout status deployment/grafana -n istio-system

# Verify
kubectl get pods -n istio-system

# Should show additional pods:
# kiali-xxx         1/1     Running
# prometheus-xxx    1/1     Running
# grafana-xxx       1/1     Running
# jaeger-xxx        1/1     Running
```

---

## 🔧 **Part 2: Configure Your Services for Istio**

### **Step 6: Enable Automatic Sidecar Injection**

```bash
# Label your namespace for automatic sidecar injection
kubectl label namespace ecommerce istio-injection=enabled

# Verify label
kubectl get namespace ecommerce --show-labels

# Should show: istio-injection=enabled
```

---

### **Step 7: Restart Your Services**

```bash
# Delete all pods to trigger sidecar injection
kubectl delete pods --all -n ecommerce

# Watch pods restart with sidecars
kubectl get pods -n ecommerce -w

# Each pod should now show 2/2 containers:
# product-service-xxx   2/2   Running  (app + istio-proxy)
# user-service-xxx      2/2   Running  (app + istio-proxy)
# frontend-service-xxx  2/2   Running  (app + istio-proxy)
```

**Press Ctrl+C to stop watching**

---

### **Step 8: Verify Sidecar Injection**

```bash
# Check sidecar status
kubectl get pods -n ecommerce -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Should show:
# product-service-xxx   product-service istio-proxy
# user-service-xxx      user-service istio-proxy
# frontend-service-xxx  frontend-service istio-proxy

# Describe a pod to see sidecar
kubectl describe pod -l app=product-service -n ecommerce | grep -A 5 "istio-proxy"
```

---

## 🌐 **Part 3: Configure Istio Gateway (Replace NGINX)**

### **Step 9: Create Istio Gateway**

```bash
# Create gateway.yaml
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: ecommerce-gateway
  namespace: ecommerce
spec:
  selector:
    istio: ingressgateway  # Use Istio's ingress gateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"  # Accept all hosts
EOF

# Verify
kubectl get gateway -n ecommerce
```

---

### **Step 10: Create VirtualService (Routing Rules)**

```bash
# Create routing rules for your services
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ecommerce-routes
  namespace: ecommerce
spec:
  hosts:
  - "*"
  gateways:
  - ecommerce-gateway
  http:
  # Product API routes
  - match:
    - uri:
        prefix: /api/products
    route:
    - destination:
        host: product-service
        port:
          number: 8081

  # User API routes
  - match:
    - uri:
        prefix: /api/users
    route:
    - destination:
        host: user-service
        port:
          number: 8080

  # Frontend routes (catch-all)
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: frontend-service
        port:
          number: 3000
EOF

# Verify
kubectl get virtualservice -n ecommerce
```

---

### **Step 11: Get Istio Ingress IP**

```bash
# Get the external IP of Istio ingress gateway
kubectl get svc istio-ingressgateway -n istio-system

# Wait for EXTERNAL-IP to be assigned (may take 2-3 minutes)

# Get the IP
ISTIO_INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Istio Ingress IP: $ISTIO_INGRESS_IP"

# Test your application
curl http://$ISTIO_INGRESS_IP/api/products
```

---

## 🔐 **Part 4: Enable mTLS**

### **Step 12: Enable Strict mTLS**

```bash
# Enforce mTLS for all services in ecommerce namespace
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: ecommerce
spec:
  mtls:
    mode: STRICT  # All service-to-service traffic must use mTLS
EOF

# Verify
kubectl get peerauthentication -n ecommerce
```

---

### **Step 13: Verify mTLS is Working**

```bash
# Check mTLS status for a service
istioctl authn tls-check product-service.ecommerce.svc.cluster.local

# Output should show:
# HOST:PORT                                    STATUS     SERVER     CLIENT
# product-service.ecommerce.svc.cluster.local  OK         STRICT     ISTIO_MUTUAL

# Check all services
istioctl authn tls-check product-service.ecommerce.svc.cluster.local user-service.ecommerce.svc.cluster.local
```

---

## 📊 **Part 5: Observability - Dashboards**

### **Step 14: Access Kiali Dashboard**

```bash
# Open Kiali (service mesh visualization)
istioctl dashboard kiali

# Opens in browser at: http://localhost:20001

# What you'll see:
# - Visual graph of service dependencies
# - Traffic flow between services
# - Health status
# - Configuration validation
```

**In Kiali:**

1. Go to **Graph** tab
2. Select namespace: `ecommerce`
3. See your services and how they communicate
4. Color-coded: green=healthy, red=errors

---

### **Step 15: Access Grafana Dashboards**

```bash
# Open Grafana
istioctl dashboard grafana

# Opens at: http://localhost:3000

# Pre-built dashboards:
# - Istio Service Dashboard
# - Istio Workload Dashboard
# - Istio Mesh Dashboard
```

**In Grafana:**

1. Browse Dashboards
2. Select "Istio Service Dashboard"
3. Choose service: product-service
4. See metrics: request rate, latency, error rate

---

### **Step 16: Access Jaeger (Distributed Tracing)**

```bash
# Open Jaeger
istioctl dashboard jaeger

# Opens at: http://localhost:16686
```

**In Jaeger:**

1. Select service: `product-service.ecommerce`
2. Click "Find Traces"
3. See request traces across multiple services
4. Click a trace to see timing breakdown

---

### **Step 17: Access Prometheus**

```bash
# Open Prometheus
istioctl dashboard prometheus

# Opens at: http://localhost:9090
```

**Query examples:**

```
# Request rate for product-service
rate(istio_requests_total{destination_service="product-service.ecommerce.svc.cluster.local"}[1m])

# Latency (p95)
histogram_quantile(0.95, istio_request_duration_milliseconds_bucket{destination_service="product-service.ecommerce.svc.cluster.local"})
```

---

## 🎯 **Part 6: Traffic Management**

### **Step 18: Canary Deployment**

Deploy v2 of product-service with 10% traffic:

```bash
# Deploy v2 (assume you have product-service:v2 image)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service-v2
  namespace: ecommerce
spec:
  replicas: 1
  selector:
    matchLabels:
      app: product-service
      version: v2
  template:
    metadata:
      labels:
        app: product-service
        version: v2
    spec:
      containers:
      - name: product-service
        image: acrecommercedev.azurecr.io/product-service:v2
        ports:
        - containerPort: 8081
EOF

# Create DestinationRule (defines subsets)
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: product-service
  namespace: ecommerce
spec:
  host: product-service
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
EOF

# Update VirtualService for traffic split
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: product-service-canary
  namespace: ecommerce
spec:
  hosts:
  - product-service
  http:
  - match:
    - uri:
        prefix: /api/products
    route:
    - destination:
        host: product-service
        subset: v1
      weight: 90  # 90% to v1
    - destination:
        host: product-service
        subset: v2
      weight: 10  # 10% to v2 (canary)
EOF
```

**Monitor in Kiali:**

- See traffic split 90/10
- Compare error rates and latency
- Gradually increase v2 traffic if it looks good

---

### **Step 19: Circuit Breaking**

Protect services from overload:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: product-service-circuit-breaker
  namespace: ecommerce
spec:
  host: product-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
EOF
```

**What this does:**

- Max 100 TCP connections
- Max 50 pending requests
- If 5 consecutive errors, eject pod for 30s
- Prevents cascading failures

---

### **Step 20: Retry Policy**

Auto-retry failed requests:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: product-retry
  namespace: ecommerce
spec:
  hosts:
  - product-service
  http:
  - route:
    - destination:
        host: product-service
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx,reset,connect-failure,refused-stream
EOF
```

**What this does:**

- Retry up to 3 times on failures
- 2-second timeout per attempt
- Retry on 5xx errors, connection failures

---

### **Step 21: Timeout Policy**

Set request timeouts:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: product-timeout
  namespace: ecommerce
spec:
  hosts:
  - product-service
  http:
  - route:
    - destination:
        host: product-service
    timeout: 5s  # Max 5 seconds per request
EOF
```

---

## 🔒 **Part 7: Advanced Security**

### **Step 22: Authorization Policies**

Control which services can call which:

```bash
# Only allow frontend to call product-service
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: product-service-authz
  namespace: ecommerce
spec:
  selector:
    matchLabels:
      app: product-service
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/ecommerce/sa/frontend-service"]
EOF

# This prevents user-service from directly calling product-service
```

---

### **Step 23: JWT Authentication**

Validate JWT tokens at the mesh level:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth
  namespace: ecommerce
spec:
  selector:
    matchLabels:
      app: user-service
  jwtRules:
  - issuer: "your-issuer"
    jwksUri: "https://your-domain/.well-known/jwks.json"
EOF
```

---

## 📈 **Part 8: Monitoring and Debugging**

### **Step 24: View Service Mesh Metrics**

```bash
# Get metrics for all services
kubectl exec -it -n ecommerce deploy/product-service -c istio-proxy -- pilot-agent request GET stats | grep product

# See live metrics:
# - Request count
# - Error rate
# - Latency percentiles
```

---

### **Step 25: Distributed Tracing**

```bash
# Generate some traffic
for i in {1..100}; do
  curl http://$ISTIO_INGRESS_IP/api/products
done

# Open Jaeger
istioctl dashboard jaeger

# Search for traces:
# 1. Service: product-service.ecommerce
# 2. Click "Find Traces"
# 3. Click on a trace
# 4. See the full request path:
#    Frontend → Product Service → Database
#    with timing for each hop
```

---

### **Step 26: Service Graph in Kiali**

```bash
# Open Kiali
istioctl dashboard kiali

# Navigate to:
# Graph → Namespace: ecommerce → Display: Versioned app graph

# You'll see:
# - All services
# - Traffic flow between them
# - Request rates
# - Error rates
# - Response times
# Color coded: Green (healthy), Red (errors)
```

---

## 🔍 **Part 9: Troubleshooting**

### **Check Proxy Status**

```bash
# Verify proxy is running
istioctl proxy-status

# Should show all your pods with SYNCED status
```

---

### **Analyze Configuration**

```bash
# Check if Istio configuration is valid
istioctl analyze -n ecommerce

# Shows any issues with your VirtualServices, DestinationRules, etc.
```

---

### **Debug Sidecar Issues**

```bash
# Check sidecar logs
kubectl logs -l app=product-service -n ecommerce -c istio-proxy

# See proxy configuration
istioctl proxy-config routes deploy/product-service -n ecommerce
```

---

### **Test mTLS**

```bash
# Verify mTLS between services
istioctl authn tls-check product-service.ecommerce.svc.cluster.local user-service.ecommerce.svc.cluster.local

# Should show: STRICT mTLS mode
```

---

## 🧪 **Part 10: Testing Features**

### **Test 1: Verify mTLS Encryption**

```bash
# Try to call product-service without going through mesh
kubectl run test-pod --rm -it --image=curlimages/curl -n default -- sh

# Inside pod:
curl http://product-service.ecommerce.svc.cluster.local:8081/api/products

# Should fail or get rejected (mTLS required)
```

---

### **Test 2: View Traffic in Real-Time**

```bash
# Open Kiali dashboard
istioctl dashboard kiali

# In another terminal, generate traffic:
while true; do
  curl http://$ISTIO_INGRESS_IP/api/products
  curl http://$ISTIO_INGRESS_IP/api/users
  sleep 1
done

# Watch the graph animate in Kiali!
```

---

### **Test 3: Fault Injection (Chaos Engineering)**

Test how your frontend handles backend failures:

```bash
# Inject 50% failure rate into product-service
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: product-fault-injection
  namespace: ecommerce
spec:
  hosts:
  - product-service
  http:
  - fault:
      abort:
        percentage:
          value: 50
        httpStatus: 503
    route:
    - destination:
        host: product-service
EOF

# Test your frontend - see how it handles errors
# Remove when done testing
```

---

### **Test 4: Traffic Mirroring (Shadow Testing)**

Mirror production traffic to v2 without affecting users:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: product-mirror
  namespace: ecommerce
spec:
  hosts:
  - product-service
  http:
  - route:
    - destination:
        host: product-service
        subset: v1
      weight: 100
    mirror:
      host: product-service
      subset: v2
    mirrorPercentage:
      value: 100
EOF

# All traffic goes to v1
# But 100% is also mirrored to v2 (for testing)
# Users see v1 responses, v2 runs in shadow
```

---

## 📚 **Part 11: Istio Resource Types**

### **Gateway**

Configures load balancer at edge of mesh for external traffic.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: my-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "*"
```

---

### **VirtualService**

Defines routing rules (like NGINX ingress rules).

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-routes
spec:
  hosts:
    - my-service
  http:
    - route:
        - destination:
            host: my-service
            subset: v1
```

---

### **DestinationRule**

Defines traffic policies for a service (load balancing, circuit breaking, subsets).

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-destination
spec:
  host: my-service
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
  subsets:
    - name: v1
      labels:
        version: v1
```

---

### **PeerAuthentication**

Controls mTLS settings.

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT
```

---

### **AuthorizationPolicy**

Controls which services can call which.

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend
spec:
  selector:
    matchLabels:
      app: product-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/ecommerce/sa/frontend"]
```

---

## 🗑️ **Uninstalling Istio**

```bash
# Remove Istio from namespace
kubectl label namespace ecommerce istio-injection-

# Remove your Istio configs
kubectl delete gateway,virtualservice,destinationrule -n ecommerce --all

# Uninstall Istio
istioctl uninstall --purge -y

# Remove namespace
kubectl delete namespace istio-system

# Clean up CRDs
kubectl get crd | grep istio | awk '{print $1}' | xargs kubectl delete crd
```

---

## 💰 **Resource Requirements**

### **Istio Resource Usage**

**Control Plane (istio-system):**

- istiod: ~500MB RAM, ~0.5 CPU
- ingress-gateway: ~200MB RAM, ~0.1 CPU
- egress-gateway: ~200MB RAM, ~0.1 CPU
- **Total:** ~900MB RAM

**Per Pod (sidecar):**

- istio-proxy: ~150MB RAM, ~0.1 CPU
- For 6 pods (3 services × 2 replicas): ~900MB RAM

**Grand Total:** ~1.8GB RAM overhead

**Your cluster:** 2 nodes × 8GB = 16GB total

- Before Istio: ~4GB used
- After Istio: ~6GB used
- **Still plenty of headroom!** ✅

---

## 🎓 **Learning Exercises**

### **Exercise 1: Trace a Request**

1. Make a request to frontend
2. Frontend calls product-service
3. View the trace in Jaeger
4. See exact timing for each hop

### **Exercise 2: Canary Deployment**

1. Deploy v2 of a service
2. Route 10% traffic to v2
3. Monitor metrics in Grafana
4. Gradually increase to 100%

### **Exercise 3: Break Things**

1. Inject faults (503 errors)
2. See how retries help
3. Test circuit breaker
4. Watch in Kiali

### **Exercise 4: Security**

1. Enable strict mTLS
2. Try to call service without proxy
3. See it blocked
4. Check certificates

---

## 📋 **Istio vs NGINX Comparison**

| Feature              | NGINX Ingress   | Istio Gateway + Mesh |
| -------------------- | --------------- | -------------------- |
| **External Traffic** | ✅ Yes          | ✅ Yes               |
| **Internal Traffic** | ❌ No control   | ✅ Full control      |
| **mTLS**             | ❌ Manual       | ✅ Automatic         |
| **Traffic Split**    | ❌ No           | ✅ Yes               |
| **Retries**          | ❌ In code      | ✅ Config            |
| **Circuit Breaking** | ❌ In code      | ✅ Config            |
| **Tracing**          | ❌ Manual setup | ✅ Automatic         |
| **Metrics**          | ❌ Manual       | ✅ Automatic         |
| **Setup Time**       | 5 min           | 20 min               |
| **Complexity**       | Low             | High                 |
| **Resource Usage**   | Low             | Medium-High          |

---

## 🎯 **Decision: Keep NGINX or Switch to Istio?**

### **Keep NGINX + Add Istio Mesh (Recommended)**

```
External Traffic → NGINX Ingress → Your Services
Internal Traffic → Istio Mesh (mTLS, retries, etc.)
```

**Pros:**

- ✅ Keep what's working (NGINX)
- ✅ Add service mesh benefits internally
- ✅ Best of both worlds

---

### **Replace NGINX with Istio Gateway**

```
All Traffic → Istio Gateway → Istio Mesh → Your Services
```

**Pros:**

- ✅ Unified solution
- ✅ One less component
- ✅ Full Istio feature set

**Cons:**

- ❌ More complex
- ❌ Istio ingress less mature than NGINX

---

## ✅ **Recommended Setup for Your Learning**

**Phase 1 (Current):**

```
NGINX Ingress
└── 3 microservices (no mesh)
```

**Phase 2 (Add Istio):**

```
NGINX Ingress (external)
└── Istio Mesh (internal)
    └── 3 microservices with sidecars
```

**Phase 3 (Full Istio):**

```
Istio Gateway (external + internal)
└── 3 microservices with sidecars
```

---

## 🚀 **Quick Installation Summary**

```bash
# Complete Istio setup in 10 commands:

# 1. Install
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.20.*
export PATH=$PWD/bin:$PATH

# 2. Install to cluster
istioctl install --set profile=demo -y

# 3. Install addons
kubectl apply -f samples/addons

# 4. Enable injection
kubectl label namespace ecommerce istio-injection=enabled

# 5. Restart pods
kubectl delete pods --all -n ecommerce

# 6. Create gateway and routes
kubectl apply -f your-gateway.yaml
kubectl apply -f your-virtualservice.yaml

# 7. Enable mTLS
kubectl apply -f peer-authentication.yaml

# 8. Open dashboards
istioctl dashboard kiali
istioctl dashboard grafana
istioctl dashboard jaeger

# Done! ✅
```

---

## 📚 **Additional Resources**

- **Official Docs:** https://istio.io/latest/docs/
- **Best Practices:** https://istio.io/latest/docs/ops/best-practices/
- **Examples:** https://github.com/istio/istio/tree/master/samples
- **Kiali Docs:** https://kiali.io/docs/
- **Traffic Management:** https://istio.io/latest/docs/tasks/traffic-management/

---

## 🎯 **Next Steps After Installation**

1. ✅ Verify all pods have 2/2 containers
2. ✅ Check mTLS is working
3. ✅ Explore Kiali dashboard
4. ✅ Try canary deployment
5. ✅ Test circuit breaker
6. ✅ View distributed traces
7. ✅ Configure authorization policies

---

## ✅ **Success Criteria**

After following this guide, you should be able to:

- [ ] Install Istio on AKS
- [ ] Inject sidecars into your services
- [ ] Verify mTLS encryption is working
- [ ] Access all dashboards (Kiali, Grafana, Jaeger)
- [ ] See service dependencies visually
- [ ] Implement traffic splitting
- [ ] Configure retries and timeouts
- [ ] View distributed traces
- [ ] Understand when to use service mesh

---

**You're now ready to add enterprise-grade service mesh to your AKS cluster!** 🚀

Start with the installation steps and explore the dashboards - you'll see your microservices in a whole new way! 🎊
