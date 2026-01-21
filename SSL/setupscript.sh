#!/bin/bash

# ============================================

# Automated SSL/TLS Setup Script

# Sets up cert-manager with Let's Encrypt

# ============================================

set -e

# Colors

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration

NAMESPACE="${NAMESPACE:-ecommerce}"
INGRESS_NAME="${INGRESS_NAME:-ecommerce-ingress}"
USE_STAGING="${USE_STAGING:-false}"

echo -e "${BLUE}=========================================="
echo "SSL/TLS Setup Script"
echo -e "==========================================${NC}"
echo ""

# Check prerequisites

echo "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
exit 1
fi

if ! command -v openssl &> /dev/null; then
echo -e "${RED}❌ openssl not found. Please install openssl first.${NC}"
exit 1
fi

echo -e "${GREEN}✅ Prerequisites met${NC}"
echo ""

# Collect configuration

echo -e "${BLUE}Configuration:${NC}"
echo ""

read -p "Enter your domain name (e.g., example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
echo -e "${RED}❌ Domain name is required${NC}"
exit 1
fi

read -p "Enter your email address (for Let's Encrypt notifications): " EMAIL
if [ -z "$EMAIL" ]; then
echo -e "${RED}❌ Email is required${NC}"
exit 1
fi

read -p "Include www subdomain? (y/n): " INCLUDE_WWW
INCLUDE_WWW=$(echo "$INCLUDE_WWW" | tr '[:upper:]' '[:lower:]')

read -p "Use staging issuer for testing? (y/n): " USE_STAGING_INPUT
if [ "$USE_STAGING_INPUT" = "y" ]; then
USE_STAGING="true"
ISSUER_NAME="letsencrypt-staging"
echo -e "${YELLOW}⚠️  Using STAGING issuer - certificates will not be trusted by browsers${NC}"
else
USE_STAGING="false"
ISSUER_NAME="letsencrypt-prod"
fi

echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo " Domain: $DOMAIN"
if [ "$INCLUDE_WWW" = "y" ]; then
echo " WWW subdomain: Yes"
fi
echo " Email: $EMAIL"
echo " Namespace: $NAMESPACE"
echo " Issuer: $ISSUER_NAME"
echo ""

read -p "Proceed with installation? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
echo "Installation cancelled."
exit 0
fi

echo ""
echo -e "${BLUE}=========================================="
echo "Step 1: Checking DNS Configuration"
echo -e "==========================================${NC}"

# Get Ingress IP

INGRESS_IP=$(kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$INGRESS_IP" ]; then
INGRESS_IP=$(kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
fi

if [ -z "$INGRESS_IP" ]; then
echo -e "${YELLOW}⚠️  Could not determine Ingress external IP${NC}"
echo "Please make sure your Ingress has an external IP/hostname assigned."
kubectl get ingress $INGRESS_NAME -n $NAMESPACE
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
exit 1
fi
else
echo -e "${GREEN}✅ Ingress IP: $INGRESS_IP${NC}"

    # Check DNS
    echo "Checking DNS resolution..."
    DNS_IP=$(nslookup $DOMAIN 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}')

    if [ "$DNS_IP" = "$INGRESS_IP" ]; then
        echo -e "${GREEN}✅ DNS correctly configured${NC}"
    else
        echo -e "${YELLOW}⚠️  DNS does not point to Ingress IP${NC}"
        echo "  Expected: $INGRESS_IP"
        echo "  Found: $DNS_IP"
        echo ""
        echo "Please configure your DNS with the following A record:"
        echo "  Type: A"
        echo "  Host: @"
        echo "  Value: $INGRESS_IP"
        echo ""
        read -p "Continue anyway? (y/n): " CONTINUE
        if [ "$CONTINUE" != "y" ]; then
            exit 1
        fi
    fi

fi

echo ""
echo -e "${BLUE}=========================================="
echo "Step 2: Installing cert-manager"
echo -e "==========================================${NC}"

# Check if cert-manager is already installed

if kubectl get namespace cert-manager &> /dev/null; then
echo -e "${YELLOW}⚠️  cert-manager namespace already exists${NC}"
read -p "Skip cert-manager installation? (y/n): " SKIP_INSTALL
if [ "$SKIP_INSTALL" = "y" ]; then
echo "Skipping cert-manager installation..."
else
echo "Reinstalling cert-manager..."
kubectl delete namespace cert-manager
fi
fi

if [ "$SKIP_INSTALL" != "y" ]; then
echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

    echo "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

    echo -e "${GREEN}✅ cert-manager installed${NC}"

fi

echo ""
echo -e "${BLUE}=========================================="
echo "Step 3: Creating ClusterIssuer"
echo -e "==========================================${NC}"

# Create ClusterIssuer

if [ "$USE_STAGING" = "true" ]; then
ACME_SERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
else
ACME_SERVER="https://acme-v02.api.letsencrypt.org/directory"
fi

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
name: $ISSUER_NAME
spec:
acme:
server: $ACME_SERVER
email: $EMAIL
privateKeySecretRef:
name: $ISSUER_NAME
solvers: - http01:
ingress:
class: nginx
EOF

echo -e "${GREEN}✅ ClusterIssuer created${NC}"

# Verify ClusterIssuer

echo "Verifying ClusterIssuer..."
sleep 5
kubectl get clusterissuer $ISSUER_NAME

echo ""
echo -e "${BLUE}=========================================="
echo "Step 4: Backing up current Ingress"
echo -e "==========================================${NC}"

BACKUP_FILE="ingress-backup-$(date +%Y%m%d-%H%M%S).yaml"
kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o yaml > $BACKUP_FILE
echo -e "${GREEN}✅ Backup saved to: $BACKUP_FILE${NC}"

echo ""
echo -e "${BLUE}=========================================="
echo "Step 5: Updating Ingress for SSL"
echo -e "==========================================${NC}"

# Build host list

HOSTS="- $DOMAIN"
if [ "$INCLUDE_WWW" = "y" ]; then
HOSTS="$HOSTS
        - www.$DOMAIN"
fi

# Create SSL-enabled Ingress

cat > /tmp/ingress-ssl.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
name: $INGRESS_NAME
  namespace: $NAMESPACE
  annotations:
    cert-manager.io/cluster-issuer: "$ISSUER_NAME"
nginx.ingress.kubernetes.io/ssl-redirect: "false" # Allow HTTP for challenge
nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
nginx.ingress.kubernetes.io/cors-enable: "true"
nginx.ingress.kubernetes.io/cors-allow-origin: "\*"
nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
spec:
ingressClassName: nginx
tls: - hosts:
$HOSTS
secretName: ${NAMESPACE}-tls
rules: - host: $DOMAIN
http:
paths: - path: /api/products
pathType: Prefix
backend:
service:
name: product-service
port:
number: 8081 - path: /api/users
pathType: Prefix
backend:
service:
name: user-service
port:
number: 8080 - path: /api/auth
pathType: Prefix
backend:
service:
name: user-service
port:
number: 8080 - path: /
pathType: Prefix
backend:
service:
name: frontend-service
port:
number: 3000
EOF

# Add www rule if needed

if [ "$INCLUDE_WWW" = "y" ]; then
cat >> /tmp/ingress-ssl.yaml <<EOF - host: www.$DOMAIN
http:
paths: - path: /api/products
pathType: Prefix
backend:
service:
name: product-service
port:
number: 8081 - path: /api/users
pathType: Prefix
backend:
service:
name: user-service
port:
number: 8080 - path: /api/auth
pathType: Prefix
backend:
service:
name: user-service
port:
number: 8080 - path: /
pathType: Prefix
backend:
service:
name: frontend-service
port:
number: 3000
EOF
fi

# Apply Ingress

kubectl apply -f /tmp/ingress-ssl.yaml

echo -e "${GREEN}✅ Ingress updated${NC}"

echo ""
echo -e "${BLUE}=========================================="
echo "Step 6: Waiting for Certificate"
echo -e "==========================================${NC}"

echo "Waiting for certificate issuance (this may take 5-10 minutes)..."
echo "You can watch progress with: kubectl get certificate -n $NAMESPACE -w"
echo ""

# Wait for certificate

TIMEOUT=600 # 10 minutes
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
CERT_STATUS=$(kubectl get certificate ${NAMESPACE}-tls -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "NotFound")

    if [ "$CERT_STATUS" = "True" ]; then
        echo -e "${GREEN}✅ Certificate issued successfully!${NC}"
        break
    elif [ "$CERT_STATUS" = "False" ]; then
        CERT_REASON=$(kubectl get certificate ${NAMESPACE}-tls -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
        echo -e "${YELLOW}Certificate status: $CERT_REASON${NC}"
    fi

    echo -n "."
    sleep 10
    ELAPSED=$((ELAPSED + 10))

done

echo ""

if [ $ELAPSED -ge $TIMEOUT ]; then
echo -e "${RED}❌ Timeout waiting for certificate${NC}"
echo "Please check certificate status manually:"
echo " kubectl describe certificate ${NAMESPACE}-tls -n $NAMESPACE"
echo " kubectl get challenge -n $NAMESPACE"
exit 1
fi

# Verify certificate

echo ""
echo "Certificate details:"
kubectl get certificate ${NAMESPACE}-tls -n $NAMESPACE

echo ""
echo -e "${BLUE}=========================================="
echo "Step 7: Enabling SSL Redirect"
echo -e "==========================================${NC}"

# Now enable SSL redirect

kubectl patch ingress $INGRESS_NAME -n $NAMESPACE --type='json' -p='[
{"op": "replace", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1ssl-redirect", "value":"true"},
{"op": "replace", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1force-ssl-redirect", "value":"true"}
]'

echo -e "${GREEN}✅ SSL redirect enabled${NC}"

echo ""
echo -e "${BLUE}=========================================="
echo "Step 8: Testing SSL Configuration"
echo -e "==========================================${NC}"

echo "Testing HTTPS connection..."
sleep 5

if curl -sSf https://$DOMAIN > /dev/null 2>&1; then
    echo -e "${GREEN}✅ HTTPS connection successful${NC}"
else
    echo -e "${YELLOW}⚠️ HTTPS connection test failed${NC}"
echo "This might be normal if DNS hasn't propagated yet."
fi

# Test certificate

echo ""
echo "Certificate details:"
echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | \
 openssl x509 -noout -dates -subject -issuer 2>/dev/null || \
 echo "Could not retrieve certificate details (this is normal if DNS hasn't propagated)"

echo ""
echo -e "${GREEN}=========================================="
echo "Installation Complete!"
echo -e "==========================================${NC}"
echo ""
echo -e "${BLUE}Your application is now secured with SSL/TLS!${NC}"
echo ""
echo "URLs:"
echo " HTTPS: https://$DOMAIN"
if [ "$INCLUDE_WWW" = "y" ]; then
echo " HTTPS (www): https://www.$DOMAIN"
fi
echo ""
echo "API Endpoints:"
echo " Products: https://$DOMAIN/api/products"
echo "  Users: https://$DOMAIN/api/users"
echo ""
echo "Certificate Details:"
echo " Issuer: $ISSUER_NAME"
echo "  Secret: ${NAMESPACE}-tls"
if [ "$USE_STAGING" = "true" ]; then
echo -e " ${YELLOW}⚠️  Using STAGING certificate (not trusted by browsers)${NC}"
echo " To use production certificates, run this script again with production issuer"
fi
echo ""
echo "Monitoring:"
echo " Check certificate: kubectl get certificate ${NAMESPACE}-tls -n $NAMESPACE"
echo " Check secret: kubectl get secret ${NAMESPACE}-tls -n $NAMESPACE"
echo " View details: kubectl describe certificate ${NAMESPACE}-tls -n $NAMESPACE"
echo ""
echo "Backup file: $BACKUP_FILE"
echo ""

if [ "$USE_STAGING" = "true" ]; then
echo -e "${YELLOW}=========================================="
    echo "Next Steps:"
    echo -e "==========================================${NC}"
echo "1. Test your application with the staging certificate"
echo "2. Once confirmed working, delete the staging certificate:"
echo " kubectl delete certificate ${NAMESPACE}-tls -n $NAMESPACE"
echo "3. Run this script again and choose production issuer"
echo ""
fi

echo "For troubleshooting, see:"
echo " kubectl logs -n cert-manager deployment/cert-manager"
echo " kubectl describe challenge -n $NAMESPACE"
echo ""

# Offer to open in browser

if command -v xdg-open &> /dev/null; then
read -p "Open https://$DOMAIN in browser? (y/n): " OPEN_BROWSER
    if [ "$OPEN_BROWSER" = "y" ]; then
xdg-open "https://$DOMAIN" &
    fi
elif command -v open &> /dev/null; then
    read -p "Open https://$DOMAIN in browser? (y/n): " OPEN_BROWSER
if [ "$OPEN_BROWSER" = "y" ]; then
open "https://$DOMAIN" &
fi
fi

echo ""
echo -e "${GREEN}Setup complete! 🎉${NC}"
