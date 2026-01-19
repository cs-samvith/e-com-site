# Kubernetes Deployment Guide

This guide explains how to deploy the microservices to Kubernetes.

---

## 📁 Folder Structure

```
kubernetes/
├── base/
│   ├── namespace.yaml
│   └── secrets/
│       ├── database-secrets.yaml
│       └── jwt-secrets.yaml
├── services/
│   ├── product-service/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   └── user-service/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── hpa.yaml
├── data-layer/
│   ├── postgres/
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   ├── redis/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── rabbitmq/
│       ├── statefulset.yaml
│       └── service.yaml
├── ingress/
│   └── ingress.yaml
├── autoscaling/
│   └── product-service-keda.yaml
└── DEPLOYMENT.md (this file)
```

---

## 🚀 Prerequisites

1. **Kubernetes Cluster** (one of):
   - Local: Minikube, Kind, Docker Desktop
   - Cloud: AKS, EKS, GKE
2. **kubectl** installed and configured

3. **Container Registry** (for images):
   - Docker Hub
   - Azure Container Registry (ACR)
   - AWS ECR
   - Google Container Registry (GCR)

---

## 📦 Step 1: Build and Push Docker Images

### Build Images

```bash
# Product Service
cd services/product-service
docker build -t <YOUR_REGISTRY>/product-service:latest .

# User Service
cd services/user-service
docker build -t <YOUR_REGISTRY>/user-service:latest .
```

### Push to Registry

```bash
# Login to your registry
docker login

# Push images
docker push <YOUR_REGISTRY>/product-service:latest
docker push <YOUR_REGISTRY>/user-service:latest
```

### Update Deployment Manifests

Edit the deployment files and replace `<YOUR_REGISTRY>` with your actual registry:

- `kubernetes/services/product-service/deployment.yaml`
- `kubernetes/services/user-service/deployment.yaml`

---

## 🔧 Step 2: Create Secrets

### Production Secrets (Recommended)

```bash
# Generate JWT secret
JWT_SECRET=$(python -c "import secrets; print(secrets.token_urlsafe(32))")

# Create namespace first
kubectl apply -f kubernetes/base/namespace.yaml

# Create database secrets
kubectl create secret generic database-secrets \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD=<STRONG_PASSWORD> \
  --from-literal=POSTGRES_HOST=postgres-service \
  --from-literal=POSTGRES_PORT=5432 \
  --from-literal=PRODUCT_DB_NAME=products_db \
  --from-literal=PRODUCT_DB_USER=postgres \
  --from-literal=PRODUCT_DB_PASSWORD=<STRONG_PASSWORD> \
  --from-literal=USER_DB_NAME=users_db \
  --from-literal=USER_DB_USER=postgres \
  --from-literal=USER_DB_PASSWORD=<STRONG_PASSWORD> \
  --from-literal=REDIS_HOST=redis-service \
  --from-literal=REDIS_PORT=6379 \
  --from-literal=RABBITMQ_HOST=rabbitmq-service \
  --from-literal=RABBITMQ_PORT=5672 \
  --from-literal=RABBITMQ_USER=guest \
  --from-literal=RABBITMQ_PASSWORD=<STRONG_PASSWORD> \
  -n ecommerce

# Create JWT secrets
kubectl create secret generic jwt-secrets \
  --from-literal=JWT_SECRET=$JWT_SECRET \
  --from-literal=JWT_ALGORITHM=HS256 \
  -n ecommerce
```

### Development Secrets (Quick Start)

For development/testing, you can use the YAML files:

```bash
kubectl apply -f kubernetes/base/namespace.yaml
kubectl apply -f kubernetes/base/secrets/
```

**⚠️ WARNING:** Never use the YAML secret files in production!

---

## 📊 Step 3: Deploy Data Layer

Deploy PostgreSQL, Redis, and RabbitMQ:

```bash
# PostgreSQL
kubectl apply -f kubernetes/data-layer/postgres/

# Redis
kubectl apply -f kubernetes/data-layer/redis/

# RabbitMQ
kubectl apply -f kubernetes/data-layer/rabbitmq/

# Verify all pods are running
kubectl get pods -n ecommerce

# Wait for all to be Ready (1/1)
kubectl wait --for=condition=ready pod -l app=postgres -n ecommerce --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n ecommerce --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n ecommerce --timeout=300s
```

---

## 🎯 Step 4: Deploy Microservices

```bash
# Product Service
kubectl apply -f kubernetes/services/product-service/

# User Service
kubectl apply -f kubernetes/services/user-service/

# Verify deployments
kubectl get deployments -n ecommerce
kubectl get pods -n ecommerce

# Check logs
kubectl logs -l app=product-service -n ecommerce
kubectl logs -l app=user-service -n ecommerce
```

---

## 🌐 Step 5: Deploy Ingress (Optional)

### Install NGINX Ingress Controller

```bash
# For Minikube
minikube addons enable ingress

# For other clusters
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

### Deploy Ingress

```bash
kubectl apply -f kubernetes/ingress/ingress.yaml

# Get ingress IP/hostname
kubectl get ingress -n ecommerce
```

### Update /etc/hosts (for local testing)

```bash
# Get Minikube IP
minikube ip

# Add to /etc/hosts (Linux/Mac) or C:\Windows\System32\drivers\etc\hosts (Windows)
<MINIKUBE_IP> ecommerce.local
```

---

## 📈 Step 6: Configure Autoscaling

### HPA (Horizontal Pod Autoscaler)

Already included in the service deployments:

- `kubernetes/services/product-service/hpa.yaml`
- `kubernetes/services/user-service/hpa.yaml`

These are applied automatically when you deploy services.

### KEDA (Event-Driven Autoscaling) - Optional

Install KEDA:

```bash
kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.12.0/keda-2.12.0.yaml
```

Deploy KEDA ScaledObjects:

```bash
kubectl apply -f kubernetes/autoscaling/product-service-keda.yaml
```

---

## 🧪 Step 7: Verify Deployment

### Check All Resources

```bash
# Check all resources in ecommerce namespace
kubectl get all -n ecommerce

# Check secrets
kubectl get secrets -n ecommerce

# Check persistent volumes
kubectl get pvc -n ecommerce
```

### Test Services

```bash
# Port-forward to test locally
kubectl port-forward -n ecommerce svc/product-service 8081:8081
kubectl port-forward -n ecommerce svc/user-service 8080:8080

# In another terminal, test endpoints
curl http://localhost:8081/health
curl http://localhost:8081/api/products

curl http://localhost:8080/health
curl http://localhost:8080/api/users
```

### Test via Ingress (if configured)

```bash
curl http://ecommerce.local/api/products
curl http://ecommerce.local/api/users
```

---

## 📊 Monitoring

### View Logs

```bash
# Product Service logs
kubectl logs -f -l app=product-service -n ecommerce

# User Service logs
kubectl logs -f -l app=user-service -n ecommerce

# PostgreSQL logs
kubectl logs -f -l app=postgres -n ecommerce
```

### Describe Resources

```bash
# Describe pod
kubectl describe pod <POD_NAME> -n ecommerce

# Describe service
kubectl describe svc product-service -n ecommerce

# Describe HPA
kubectl describe hpa product-service-hpa -n ecommerce
```

### Check Events

```bash
kubectl get events -n ecommerce --sort-by='.lastTimestamp'
```

---

## 🔄 Updates and Rollbacks

### Update Deployment

```bash
# Update image
kubectl set image deployment/product-service \
  product-service=<YOUR_REGISTRY>/product-service:v2 \
  -n ecommerce

# Check rollout status
kubectl rollout status deployment/product-service -n ecommerce

# Check rollout history
kubectl rollout history deployment/product-service -n ecommerce
```

### Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/product-service -n ecommerce

# Rollback to specific revision
kubectl rollout undo deployment/product-service --to-revision=2 -n ecommerce
```

---

## 🗑️ Cleanup

### Delete Services Only

```bash
kubectl delete -f kubernetes/services/product-service/
kubectl delete -f kubernetes/services/user-service/
```

### Delete Everything

```bash
# Delete entire namespace (removes everything)
kubectl delete namespace ecommerce

# Or delete individual components
kubectl delete -f kubernetes/services/
kubectl delete -f kubernetes/data-layer/
kubectl delete -f kubernetes/ingress/
kubectl delete -f kubernetes/base/
```

---

## 🐛 Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n ecommerce

# Check pod events
kubectl describe pod <POD_NAME> -n ecommerce

# Check logs
kubectl logs <POD_NAME> -n ecommerce

# If container keeps crashing
kubectl logs <POD_NAME> -n ecommerce --previous
```

### ImagePullBackOff Error

```bash
# Verify image exists in registry
docker pull <YOUR_REGISTRY>/product-service:latest

# Check image pull secret if using private registry
kubectl get secrets -n ecommerce
```

### Database Connection Issues

```bash
# Check if PostgreSQL is running
kubectl get pods -l app=postgres -n ecommerce

# Test connection from a pod
kubectl run test-pod --rm -it --image=postgres:15 -n ecommerce -- bash
psql -h postgres-service -U postgres -d products_db
```

### Service Not Accessible

```bash
# Check service
kubectl get svc -n ecommerce

# Check endpoints
kubectl get endpoints product-service -n ecommerce

# Port-forward to test
kubectl port-forward svc/product-service 8081:8081 -n ecommerce
```

---

## 📚 Next Steps

1. **Add Monitoring**: Deploy Prometheus + Grafana
2. **Add Logging**: Deploy ELK/Loki stack
3. **Add Tracing**: Deploy Jaeger
4. **Configure Service Mesh**: Install Istio
5. **Set up CI/CD**: GitHub Actions / Azure DevOps
6. **Configure Network Policies**: Restrict pod communication
7. **Add Certificate Management**: cert-manager for TLS

---

## 🎯 Quick Commands Reference

```bash
# Deploy everything
kubectl apply -f kubernetes/base/
kubectl apply -f kubernetes/data-layer/
kubectl apply -f kubernetes/services/
kubectl apply -f kubernetes/ingress/

# Check status
kubectl get all -n ecommerce

# View logs
kubectl logs -f -l app=product-service -n ecommerce

# Port forward
kubectl port-forward svc/product-service 8081:8081 -n ecommerce

# Scale manually
kubectl scale deployment product-service --replicas=5 -n ecommerce

# Delete everything
kubectl delete namespace ecommerce
```

---

Happy deploying! 🚀
