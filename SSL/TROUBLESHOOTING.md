# SSL/TLS Troubleshooting Guide

## 🚨 Common Issues & Solutions

### Issue 1: Certificate Not Being Issued

**Symptoms:**

```bash
kubectl get certificate -n ecommerce
# Shows: Ready=False, Status=Pending
```

**Diagnosis:**

```bash
# Check certificate details
kubectl describe certificate ecommerce-tls -n ecommerce

# Check certificate request
kubectl get certificaterequest -n ecommerce
kubectl describe certificaterequest -n ecommerce

# Check challenge
kubectl get challenge -n ecommerce
kubectl describe challenge -n ecommerce
```

**Common Causes:**

**A. DNS Not Configured**

```bash
# Verify DNS points to Ingress IP
nslookup yourdomain.com

# Should return your Ingress external IP
# If not, wait for DNS propagation (can take up to 48 hours)
```

**Solution:**

```bash
# Check your Ingress IP
kubectl get ingress ecommerce-ingress -n ecommerce -o wide

# Update your DNS A record to point to this IP
```

**B. HTTP-01 Challenge Failing**

```bash
# Test if /.well-known/acme-challenge/ is accessible
curl http://yourdomain.com/.well-known/acme-challenge/test

# Should NOT return 404
```

**Solution:**

```yaml
# Make sure your Ingress allows HTTP (port 80)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    # Don't force HTTPS redirect during certificate issuance
    nginx.ingress.kubernetes.io/ssl-redirect: "false" # ← Change to false temporarily
```

**C. Rate Limiting (Let's Encrypt)**

```
Error: too many certificates already issued
```

**Solution:**

```bash
# Use staging issuer for testing
kubectl patch ingress ecommerce-ingress -n ecommerce \
  --type='json' -p='[{"op": "replace", "path": "/metadata/annotations/cert-manager.io~1cluster-issuer", "value":"letsencrypt-staging"}]'

# Once working, switch back to prod
```

---

### Issue 2: Browser Shows "Not Secure"

**Symptoms:**

- Browser shows warning
- Certificate is from "Kubernetes Ingress Controller Fake Certificate"

**Diagnosis:**

```bash
# Check if certificate is ready
kubectl get certificate ecommerce-tls -n ecommerce

# Check TLS secret exists
kubectl get secret ecommerce-tls -n ecommerce

# Inspect certificate
kubectl get secret ecommerce-tls -n ecommerce -o yaml
```

**Solutions:**

**A. Certificate Not Ready Yet**

```bash
# Wait for certificate (can take 5-10 minutes)
kubectl wait --for=condition=ready certificate ecommerce-tls -n ecommerce --timeout=600s
```

**B. Wrong Secret Name**

```yaml
# Make sure secret name matches in Ingress
spec:
  tls:
    - hosts:
        - yourdomain.com
      secretName: ecommerce-tls # ← Must match certificate name
```

**C. Cert-manager Not Watching**

```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager -f

# Restart cert-manager if needed
kubectl rollout restart deployment cert-manager -n cert-manager
```

---

### Issue 3: Mixed Content Warnings

**Symptoms:**

- Page loads but some resources blocked
- Console shows: "Mixed Content: The page was loaded over HTTPS, but requested an insecure resource"

**Solution:**

**Frontend (Next.js):**

```typescript
// next.config.js
module.exports = {
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          {
            key: "Content-Security-Policy",
            value: "upgrade-insecure-requests",
          },
        ],
      },
    ];
  },
};
```

**Ingress:**

```yaml
annotations:
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

---

### Issue 4: Certificate Expired

**Symptoms:**

```bash
kubectl get certificate -n ecommerce
# Shows: Ready=False, Status=Expired
```

**Solution:**

```bash
# cert-manager should auto-renew 30 days before expiry
# If not, manually trigger renewal:

# Delete the secret (cert-manager will recreate)
kubectl delete secret ecommerce-tls -n ecommerce

# Wait for recreation
kubectl wait --for=condition=ready certificate ecommerce-tls -n ecommerce --timeout=300s
```

---

### Issue 5: CORS Errors with HTTPS

**Symptoms:**

- API calls work with HTTP but fail with HTTPS
- Console shows CORS error

**Solution:**

**Option A: Configure Ingress**

```yaml
annotations:
  nginx.ingress.kubernetes.io/cors-enable: "true"
  nginx.ingress.kubernetes.io/cors-allow-origin: "https://yourdomain.com"
  nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
  nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
```

**Option B: Configure FastAPI**

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://yourdomain.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

---

## 🔍 Diagnostic Commands

### Check Certificate Status

```bash
# List all certificates
kubectl get certificate -A

# Detailed certificate info
kubectl describe certificate ecommerce-tls -n ecommerce

# Check certificate expiry
kubectl get secret ecommerce-tls -n ecommerce -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | \
  openssl x509 -noout -dates

# View full certificate details
kubectl get secret ecommerce-tls -n ecommerce -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | \
  openssl x509 -noout -text
```

### Check cert-manager

```bash
# cert-manager pods
kubectl get pods -n cert-manager

# cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager -f

# cert-manager webhook logs
kubectl logs -n cert-manager deployment/cert-manager-webhook -f

# Check ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

### Test HTTPS Connection

```bash
# Test SSL/TLS connection
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com

# Check certificate from browser perspective
curl -vI https://yourdomain.com 2>&1 | grep -A 10 "Server certificate"

# Test with specific SSL version
curl --tlsv1.2 https://yourdomain.com
curl --tlsv1.3 https://yourdomain.com
```

### Test from Inside Cluster

```bash
# Create test pod
kubectl run test-curl --image=curlimages/curl -it --rm -- sh

# Inside the pod:
curl -k https://frontend-service.ecommerce.svc.cluster.local:443
```

---

## 📋 Quick Reference Card

### cert-manager Certificate Lifecycle

```
1. Ingress created with cert-manager annotation
   ↓
2. cert-manager detects annotation
   ↓
3. Certificate resource created
   ↓
4. CertificateRequest created
   ↓
5. Order created with ACME server
   ↓
6. Challenge created (HTTP-01)
   ↓
7. ACME server validates challenge
   ↓
8. Certificate issued
   ↓
9. Secret created with cert & key
   ↓
10. Ingress uses secret for TLS
```

### Important Annotations

```yaml
# cert-manager
cert-manager.io/cluster-issuer: "letsencrypt-prod"
cert-manager.io/common-name: "yourdomain.com"
cert-manager.io/duration: "2160h" # 90 days
cert-manager.io/renew-before: "720h" # 30 days

# NGINX Ingress
nginx.ingress.kubernetes.io/ssl-redirect: "true"
nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
nginx.ingress.kubernetes.io/ssl-ciphers: "HIGH:!aNULL:!MD5"

# HSTS (HTTP Strict Transport Security)
nginx.ingress.kubernetes.io/hsts: "true"
nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
nginx.ingress.kubernetes.io/hsts-preload: "true"
```

### Certificate States

| State                         | Meaning                      | Action             |
| ----------------------------- | ---------------------------- | ------------------ |
| `Ready=True`                  | Certificate valid and active | ✅ None            |
| `Ready=False, Status=Pending` | Being issued                 | ⏳ Wait (5-10 min) |
| `Ready=False, Status=Failed`  | Issuance failed              | 🔍 Check logs      |
| `Ready=False, Status=Expired` | Certificate expired          | 🔄 Renew           |

---

## 🛠️ Maintenance Tasks

### Force Certificate Renewal

```bash
# Method 1: Delete and recreate
kubectl delete certificate ecommerce-tls -n ecommerce
# cert-manager will recreate it

# Method 2: Delete secret
kubectl delete secret ecommerce-tls -n ecommerce
# cert-manager will recreate it

# Method 3: Add annotation
kubectl annotate certificate ecommerce-tls -n ecommerce \
  cert-manager.io/issue-temporary-certificate="true" --overwrite
```

### Backup Certificates

```bash
# Backup TLS secret
kubectl get secret ecommerce-tls -n ecommerce -o yaml > ecommerce-tls-backup.yaml

# Restore
kubectl apply -f ecommerce-tls-backup.yaml
```

### Monitor Certificate Expiry

```bash
# Check expiry date
kubectl get secret ecommerce-tls -n ecommerce -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | \
  openssl x509 -noout -enddate

# Set up alert (example using kubectl)
cat > check-cert-expiry.sh <<'EOF'
#!/bin/bash
EXPIRY=$(kubectl get secret ecommerce-tls -n ecommerce -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | \
  openssl x509 -noout -enddate | \
  cut -d= -f2)

EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

echo "Certificate expires in $DAYS_LEFT days"

if [ $DAYS_LEFT -lt 30 ]; then
  echo "WARNING: Certificate expires in less than 30 days!"
fi
EOF

chmod +x check-cert-expiry.sh
```

---

## 🔐 Security Best Practices

### 1. Use Strong TLS Settings

```yaml
annotations:
  # Only allow TLS 1.2 and 1.3
  nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"

  # Use strong ciphers
  nginx.ingress.kubernetes.io/ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"

  # Enable HSTS
  nginx.ingress.kubernetes.io/hsts: "true"
  nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
  nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
```

### 2. Regular Certificate Rotation

```bash
# cert-manager auto-renews 30 days before expiry
# Verify auto-renewal is working:
kubectl get certificate -n ecommerce -o yaml | grep "renew-before"
```

### 3. Secure Secret Storage

```bash
# Encrypt secrets at rest (AKS)
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --addons azure-keyvault-secrets-provider
```

### 4. Test SSL Configuration

Use online tools:

- https://www.ssllabs.com/ssltest/
- https://securityheaders.com/

---

## 📞 Getting Help

### cert-manager Community

- Documentation: https://cert-manager.io/docs/
- GitHub Issues: https://github.com/cert-manager/cert-manager/issues
- Slack: https://cert-manager.io/docs/contributing/

### Let's Encrypt

- Status: https://letsencrypt.status.io/
- Rate Limits: https://letsencrypt.org/docs/rate-limits/
- Community: https://community.letsencrypt.org/

### Useful Debug Tools

```bash
# SSL Labs command-line tool
docker run --rm -it jumanjiman/ssllabs-scan yourdomain.com

# Test SSL/TLS
testssl.sh https://yourdomain.com
```

---

## ✅ Pre-Deployment Checklist

- [ ] Domain registered and accessible
- [ ] DNS A record points to Ingress IP
- [ ] DNS propagated (check with `nslookup`)
- [ ] cert-manager installed and running
- [ ] ClusterIssuer created
- [ ] Email in ClusterIssuer is correct
- [ ] Ingress has cert-manager annotation
- [ ] TLS section configured in Ingress
- [ ] HTTP (port 80) accessible for challenges
- [ ] Tested with staging issuer first
- [ ] Switched to production issuer
- [ ] Certificate shows Ready=True
- [ ] Browser shows secure connection
- [ ] No mixed content warnings
- [ ] All API endpoints work over HTTPS
- [ ] Auto-renewal working (check renew-before)
