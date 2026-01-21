# Complete DNS Guide for Kubernetes Applications

## From Zero to Production-Ready DNS Configuration

---

## 📋 Table of Contents

1. [DNS Basics](#dns-basics)
2. [Understanding DNS Records](#understanding-dns-records)
3. [DNS for Kubernetes Applications](#dns-for-kubernetes-applications)
4. [Step-by-Step DNS Setup](#step-by-step-dns-setup)
5. [DNS Providers Configuration](#dns-providers-configuration)
6. [Azure-Specific DNS Setup](#azure-specific-dns-setup)
7. [Testing and Verification](#testing-and-verification)
8. [Troubleshooting](#troubleshooting)
9. [Advanced DNS Configuration](#advanced-dns-configuration)
10. [Best Practices](#best-practices)

---

## DNS Basics

### What is DNS?

**DNS (Domain Name System)** is the internet's phonebook. It translates human-readable domain names (like `myapp.com`) into IP addresses (like `20.123.45.67`) that computers use to communicate.

```
User types: myapp.com
     ↓
DNS Server translates
     ↓
Returns: 20.123.45.67
     ↓
Browser connects to IP
```

### Why DNS Matters for Your Application

Without DNS:

```bash
# Users must access your app like this:
http://20.123.45.67

# ❌ Hard to remember
# ❌ Not professional
# ❌ Can't use SSL certificates
# ❌ Changes if you redeploy
```

With DNS:

```bash
# Users access your app like this:
https://myapp.com

# ✅ Easy to remember
# ✅ Professional
# ✅ SSL/TLS support
# ✅ IP can change without affecting users
```

### DNS Hierarchy

```
Root DNS Servers (.)
    ↓
Top-Level Domain (TLD) Servers (.com, .org, .net)
    ↓
Authoritative Name Servers (your-domain.com)
    ↓
Your Records (www.your-domain.com, api.your-domain.com)
```

---

## Understanding DNS Records

### Common Record Types

| Record Type | Purpose                 | Example                                 | Use Case           |
| ----------- | ----------------------- | --------------------------------------- | ------------------ |
| **A**       | Maps domain to IPv4     | `myapp.com → 20.123.45.67`              | Main domain        |
| **AAAA**    | Maps domain to IPv6     | `myapp.com → 2001:db8::1`               | IPv6 support       |
| **CNAME**   | Alias to another domain | `www → myapp.com`                       | Subdomain redirect |
| **MX**      | Mail server             | `mail.myapp.com`                        | Email routing      |
| **TXT**     | Text information        | `"v=spf1 include:_spf.google.com ~all"` | Verification, SPF  |
| **NS**      | Name server             | `ns1.provider.com`                      | Delegation         |
| **SOA**     | Start of Authority      | Zone information                        | Zone management    |

### A Record (Address Record)

**Most common for Kubernetes applications**

```
Type: A
Host: @ (or blank for root domain)
Value: 20.123.45.67
TTL: 3600
```

**What it means:**

- `@` or blank = root domain (myapp.com)
- Points directly to your Ingress IP address
- IPv4 address only

**Example:**

```
myapp.com → 20.123.45.67
```

### AAAA Record (IPv6)

Same as A record but for IPv6:

```
Type: AAAA
Host: @
Value: 2001:0db8:85a3:0000:0000:8a2e:0370:7334
TTL: 3600
```

### CNAME Record (Canonical Name)

Creates an alias from one domain to another:

```
Type: CNAME
Host: www
Value: myapp.com
TTL: 3600
```

**Result:**

```
www.myapp.com → myapp.com → 20.123.45.67
```

**Important Rules:**

- ✅ Can use for subdomains (www, api, blog)
- ❌ Cannot use for root domain (@)
- ❌ Cannot coexist with other records on same host

### TXT Record

Stores text information:

```
Type: TXT
Host: @
Value: "v=spf1 include:_spf.google.com ~all"
TTL: 3600
```

**Common uses:**

- Domain verification (Google, Microsoft)
- SPF records for email
- DKIM signatures
- Site ownership verification

### MX Record (Mail Exchange)

For email routing:

```
Type: MX
Host: @
Value: mail.myapp.com
Priority: 10
TTL: 3600
```

### NS Record (Name Server)

Specifies authoritative name servers:

```
Type: NS
Host: @
Value: ns1.provider.com
TTL: 86400
```

### TTL (Time To Live)

**TTL** determines how long DNS records are cached:

```
TTL: 300     = 5 minutes   (for frequent changes)
TTL: 3600    = 1 hour      (default, balanced)
TTL: 86400   = 24 hours    (stable, rarely changes)
```

**Lower TTL = Faster propagation, more DNS queries**
**Higher TTL = Slower propagation, less DNS queries**

---

## DNS for Kubernetes Applications

### Your Typical Setup

```
┌─────────────────────────────────────────────┐
│          Domain Registrar                    │
│        (GoDaddy, Namecheap, etc.)           │
│                                              │
│  DNS Records:                                │
│  • myapp.com       → A → 20.123.45.67       │
│  • www.myapp.com   → CNAME → myapp.com      │
│  • api.myapp.com   → A → 20.123.45.67       │
└─────────────────────────────────────────────┘
                    ↓
                    ↓ DNS Resolution
                    ↓
┌─────────────────────────────────────────────┐
│      Azure Kubernetes Service (AKS)         │
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │  Load Balancer (External IP)           │ │
│  │  IP: 20.123.45.67                      │ │
│  └────────────────────────────────────────┘ │
│                    ↓                         │
│  ┌────────────────────────────────────────┐ │
│  │  NGINX Ingress Controller              │ │
│  └────────────────────────────────────────┘ │
│                    ↓                         │
│  ┌──────────┬──────────┬──────────────────┐ │
│  │ Frontend │ Product  │ User             │ │
│  │ Service  │ Service  │ Service          │ │
│  └──────────┴──────────┴──────────────────┘ │
└─────────────────────────────────────────────┘
```

### What You Need

1. **Domain name** (purchased from registrar)
2. **Ingress external IP** (from Kubernetes)
3. **DNS records** (configured at registrar)

---

## Step-by-Step DNS Setup

### Phase 1: Get Your Ingress External IP

```bash
# Get your Ingress external IP
kubectl get ingress ecommerce-ingress -n ecommerce

# Output:
# NAME                 CLASS   HOSTS   ADDRESS          PORTS   AGE
# ecommerce-ingress    nginx   *       20.123.45.67     80      10m
```

**Note the ADDRESS:** `20.123.45.67` (this is your external IP)

If you see `<pending>`:

```bash
# Wait for LoadBalancer to provision
kubectl get ingress ecommerce-ingress -n ecommerce -w

# Or check the service
kubectl get svc -n ingress-nginx
```

### Phase 2: Choose Your Domain

**Option 1: Buy a new domain**

- GoDaddy: https://www.godaddy.com
- Namecheap: https://www.namecheap.com
- Google Domains: https://domains.google
- Cloudflare: https://www.cloudflare.com/products/registrar

**Option 2: Use existing domain**

- Log into your domain registrar
- Find DNS management section

**Option 3: Use subdomain**

- If you have `company.com`, use `myapp.company.com`

### Phase 3: Configure DNS Records

**Minimum Configuration (Root domain only):**

```
Type: A
Host: @ (or blank)
Value: 20.123.45.67
TTL: 3600
```

**Recommended Configuration (With www subdomain):**

```
# Root domain
Type: A
Host: @
Value: 20.123.45.67
TTL: 3600

# WWW subdomain
Type: CNAME
Host: www
Value: myapp.com
TTL: 3600
```

**Full Configuration (Multiple subdomains):**

```
# Root domain
Type: A
Host: @
Value: 20.123.45.67
TTL: 3600

# WWW subdomain
Type: CNAME
Host: www
Value: myapp.com
TTL: 3600

# API subdomain (optional)
Type: A
Host: api
Value: 20.123.45.67
TTL: 3600

# Staging subdomain (optional)
Type: A
Host: staging
Value: 20.123.45.68
TTL: 3600
```

### Phase 4: Wait for DNS Propagation

DNS changes take time to propagate:

- **Local cache:** 5-15 minutes
- **ISP cache:** 1-4 hours
- **Global propagation:** 24-48 hours (usually much faster)

**Typical timeline:**

```
0 min:    Changes saved at registrar
5 min:    Your local computer can resolve
30 min:   Most nearby servers can resolve
2 hours:  Most global servers can resolve
24 hours: Fully propagated worldwide
```

### Phase 5: Verify DNS Configuration

```bash
# Check DNS resolution
nslookup myapp.com

# Expected output:
# Server:  8.8.8.8
# Address: 8.8.8.8#53
#
# Non-authoritative answer:
# Name:    myapp.com
# Address: 20.123.45.67

# Alternative: Use dig
dig myapp.com

# Check from multiple locations
dig myapp.com @8.8.8.8          # Google DNS
dig myapp.com @1.1.1.1          # Cloudflare DNS
dig myapp.com @208.67.222.222   # OpenDNS
```

---

## DNS Providers Configuration

### GoDaddy

**1. Log in to GoDaddy**

- Go to https://www.godaddy.com
- Click "Sign In"
- Navigate to "My Products"

**2. Manage DNS**

- Find your domain
- Click "DNS" button
- Or click "Manage" → "DNS"

**3. Add A Record**

```
Type: A
Name: @
Value: 20.123.45.67
TTL: 1 Hour (or Custom: 3600)
```

**4. Add CNAME for www**

```
Type: CNAME
Name: www
Value: @ (or myapp.com)
TTL: 1 Hour
```

**5. Save Changes**

- Click "Save" or "Add Record"
- Wait 10-30 minutes for propagation

**GoDaddy Specific Notes:**

- `@` represents root domain
- TTL in hours or seconds
- Changes typically propagate in 10-30 minutes
- May need to remove default parking page records

### Namecheap

**1. Log in to Namecheap**

- Go to https://www.namecheap.com
- Click "Sign In"
- Navigate to "Domain List"

**2. Manage Domain**

- Click "Manage" next to your domain
- Click "Advanced DNS" tab

**3. Add A Record**

```
Type: A Record
Host: @
Value: 20.123.45.67
TTL: Automatic (or 3600)
```

**4. Add CNAME**

```
Type: CNAME Record
Host: www
Value: myapp.com
TTL: Automatic
```

**5. Save Changes**

- Scroll down and click green checkmark

**Namecheap Specific Notes:**

- Very user-friendly interface
- "Automatic" TTL = 3600 seconds
- Remove default URL Redirect Record if present
- Parking Page might interfere - disable it

### Google Domains

**1. Log in to Google Domains**

- Go to https://domains.google.com
- Click on your domain

**2. Navigate to DNS**

- Click "DNS" in left sidebar
- Scroll to "Custom records"

**3. Add Records**

```
# A Record
Name: @
Type: A
TTL: 3600
Data: 20.123.45.67

# CNAME Record
Name: www
Type: CNAME
TTL: 3600
Data: myapp.com.
```

**Note:** Google Domains adds trailing dot automatically

**4. Save Changes**

**Google Domains Specific Notes:**

- Very clean interface
- TTL in seconds only
- Automatically adds trailing dot to CNAME targets
- Fast propagation (usually 10-15 minutes)

### Cloudflare

**1. Add Site to Cloudflare**

- Go to https://dash.cloudflare.com
- Click "Add a Site"
- Enter your domain
- Choose plan (Free works fine)

**2. Update Nameservers**

- Cloudflare will provide nameservers
- Update at your registrar:

```
ns1.cloudflare.com
ns2.cloudflare.com
```

**3. Add DNS Records**

- Navigate to DNS section
- Add A record:

```
Type: A
Name: @
IPv4 address: 20.123.45.67
Proxy status: DNS only (grey cloud)
TTL: Auto
```

**4. Add CNAME**

```
Type: CNAME
Name: www
Target: myapp.com
Proxy status: DNS only
TTL: Auto
```

**Cloudflare Specific Notes:**

- Offers CDN/Proxy (orange cloud) - keep as "DNS only" (grey cloud) for initial setup
- Built-in DDoS protection
- Free SSL certificates
- Very fast propagation
- Analytics included

**Proxy Status:**

- 🟠 **Proxied (Orange Cloud):** Traffic goes through Cloudflare CDN
- ⚫ **DNS Only (Grey Cloud):** Direct to your server (use this for Kubernetes)

### Azure DNS

**1. Create DNS Zone**

```bash
# Create DNS zone
az network dns zone create \
  --resource-group rg-ecommerce-aks-dev \
  --name myapp.com

# Get nameservers
az network dns zone show \
  --resource-group rg-ecommerce-aks-dev \
  --name myapp.com \
  --query nameServers
```

**2. Update Nameservers at Registrar**
Update your domain registrar to use Azure nameservers:

```
ns1-01.azure-dns.com
ns2-01.azure-dns.net
ns3-01.azure-dns.org
ns4-01.azure-dns.info
```

**3. Create DNS Records**

```bash
# Create A record
az network dns record-set a add-record \
  --resource-group rg-ecommerce-aks-dev \
  --zone-name myapp.com \
  --record-set-name @ \
  --ipv4-address 20.123.45.67

# Create CNAME record
az network dns record-set cname set-record \
  --resource-group rg-ecommerce-aks-dev \
  --zone-name myapp.com \
  --record-set-name www \
  --cname myapp.com
```

**4. Verify Records**

```bash
# List all records
az network dns record-set list \
  --resource-group rg-ecommerce-aks-dev \
  --zone-name myapp.com
```

### Route 53 (AWS)

**1. Create Hosted Zone**

- Navigate to Route 53
- Click "Create Hosted Zone"
- Enter domain name
- Choose "Public Hosted Zone"

**2. Update Nameservers**

- Copy the 4 NS records
- Update at your registrar

**3. Create Record Sets**

```
Type: A
Name: (blank for root)
Value: 20.123.45.67
TTL: 300
Routing Policy: Simple

Type: CNAME
Name: www
Value: myapp.com
TTL: 300
Routing Policy: Simple
```

---

## Azure-Specific DNS Setup

### Scenario 1: Using Azure DNS

**Complete setup:**

```bash
#!/bin/bash

RESOURCE_GROUP="rg-ecommerce-aks-dev"
DOMAIN="myapp.com"
INGRESS_IP="20.123.45.67"

# 1. Create DNS zone
az network dns zone create \
  --resource-group $RESOURCE_GROUP \
  --name $DOMAIN

# 2. Get nameservers (update at registrar)
az network dns zone show \
  --resource-group $RESOURCE_GROUP \
  --name $DOMAIN \
  --query nameServers

echo "Update your domain registrar with these nameservers ^"
read -p "Press enter when done..."

# 3. Create A record for root domain
az network dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DOMAIN \
  --record-set-name @ \
  --ipv4-address $INGRESS_IP

# 4. Create CNAME for www
az network dns record-set cname set-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DOMAIN \
  --record-set-name www \
  --cname $DOMAIN

# 5. Verify
az network dns record-set list \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DOMAIN \
  --output table

echo "DNS setup complete!"
```

### Scenario 2: Using External DNS with Azure DNS

**External DNS** automatically creates DNS records based on your Ingress resources.

**1. Install External DNS**

```bash
# Create service principal
az ad sp create-for-rbac --name external-dns-sp

# Note the output: appId, password, tenant

# Create secret
kubectl create secret generic azure-config-file \
  --namespace default \
  --from-literal=azure.json='{
    "tenantId": "your-tenant-id",
    "subscriptionId": "your-subscription-id",
    "resourceGroup": "rg-ecommerce-aks-dev",
    "aadClientId": "your-app-id",
    "aadClientSecret": "your-password"
  }'
```

**2. Deploy External DNS**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
spec:
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
        - name: external-dns
          image: k8s.gcr.io/external-dns/external-dns:v0.13.5
          args:
            - --source=ingress
            - --provider=azure
            - --azure-resource-group=rg-ecommerce-aks-dev
            - --azure-subscription-id=your-subscription-id
          volumeMounts:
            - name: azure-config-file
              mountPath: /etc/kubernetes
              readOnly: true
      volumes:
        - name: azure-config-file
          secret:
            secretName: azure-config-file
```

**3. Update Ingress**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-ingress
  namespace: ecommerce
  annotations:
    external-dns.alpha.kubernetes.io/hostname: myapp.com,www.myapp.com
spec:
  rules:
    - host: myapp.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 3000
```

**External DNS will automatically:**

- Create A record for myapp.com
- Create A record for www.myapp.com
- Update records when IP changes
- Remove records when Ingress is deleted

---

## Testing and Verification

### Basic DNS Tests

**1. Check if domain resolves**

```bash
# Using nslookup
nslookup myapp.com

# Using dig
dig myapp.com

# Using host
host myapp.com
```

**2. Check specific record types**

```bash
# A record
dig A myapp.com

# AAAA record (IPv6)
dig AAAA myapp.com

# CNAME record
dig CNAME www.myapp.com

# All records
dig ANY myapp.com
```

**3. Check from specific DNS server**

```bash
# Google DNS
dig @8.8.8.8 myapp.com

# Cloudflare DNS
dig @1.1.1.1 myapp.com

# OpenDNS
dig @208.67.222.222 myapp.com
```

### Propagation Checking Tools

**Online tools:**

- https://dnschecker.org
- https://www.whatsmydns.net
- https://mxtoolbox.com/SuperTool.aspx

**Command line:**

```bash
# Check from multiple locations
for server in 8.8.8.8 1.1.1.1 208.67.222.222 9.9.9.9; do
  echo "Checking with $server:"
  dig @$server myapp.com +short
done
```

### TTL Verification

```bash
# Check TTL
dig myapp.com | grep -A1 "ANSWER SECTION"

# Output example:
# myapp.com.    3600    IN    A    20.123.45.67
#                ↑ This is the TTL in seconds
```

### Full DNS Diagnostic

```bash
# Complete DNS check
dig myapp.com +trace

# Shows complete resolution path:
# 1. Root servers
# 2. TLD servers (.com)
# 3. Authoritative nameservers
# 4. Final A record
```

### Test from Your Application

**Python:**

```python
import socket
print(socket.gethostbyname('myapp.com'))
```

**Node.js:**

```javascript
const dns = require("dns");
dns.lookup("myapp.com", (err, address) => {
  console.log(address);
});
```

**Bash:**

```bash
curl -I http://myapp.com
# Should connect successfully
```

---

## Troubleshooting

### Issue 1: Domain Not Resolving

**Symptoms:**

```bash
nslookup myapp.com
# Server can't find myapp.com: NXDOMAIN
```

**Possible causes:**

**A. DNS records not yet propagated**

```bash
# Check when you made changes
# If less than 1 hour ago, wait longer

# Check if working from some servers
dig @8.8.8.8 myapp.com
dig @1.1.1.1 myapp.com
```

**B. Incorrect nameservers**

```bash
# Check nameservers
dig NS myapp.com

# Should match registrar's nameservers
```

**C. Typo in DNS record**

- Double-check IP address
- Verify no extra spaces
- Check record type is "A" not "AAAA"

**D. DNS cache**

```bash
# Flush local DNS cache

# macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns
```

### Issue 2: www Works But Root Doesn't (or vice versa)

**Symptoms:**

- `www.myapp.com` works
- `myapp.com` doesn't work

**Solution:**

```bash
# Make sure both records exist

# Check A record for root
dig A myapp.com

# Check CNAME for www
dig CNAME www.myapp.com

# Add missing record at your registrar
```

### Issue 3: Intermittent Resolution

**Symptoms:**

- Sometimes resolves, sometimes doesn't
- Works from some networks, not others

**Possible causes:**

**A. Propagation in progress**

- Wait 24-48 hours for full propagation

**B. Cached old records**

```bash
# Check TTL
dig myapp.com | grep TTL

# If high TTL (86400), old records cached for 24 hours
# Lower TTL for future changes
```

**C. Multiple DNS records**

```bash
# Check for duplicates
dig myapp.com

# Should show one clear A record
# If multiple, remove duplicates at registrar
```

### Issue 4: SSL Certificate Issues

**Symptoms:**

- DNS works
- HTTP works
- HTTPS fails with certificate error

**Check:**

```bash
# Verify DNS in certificate
echo | openssl s_client -servername myapp.com -connect myapp.com:443 2>/dev/null | openssl x509 -noout -text | grep DNS

# Should show your domain
```

**Solution:**

- Ensure cert-manager has correct domain
- Check Certificate resource in Kubernetes
- Verify Ingress TLS section has correct hostname

### Issue 5: DNS Works But Site Doesn't Load

**Symptoms:**

```bash
nslookup myapp.com
# Returns: 20.123.45.67 ✅

curl http://myapp.com
# Connection refused or timeout ❌
```

**Diagnosis:**

```bash
# 1. Check if IP is correct
kubectl get ingress -n ecommerce

# 2. Check if Ingress controller is running
kubectl get pods -n ingress-nginx

# 3. Check if services are running
kubectl get svc -n ecommerce

# 4. Test direct IP connection
curl http://20.123.45.67

# If this works, DNS is fine, issue is with Ingress config
```

---

## Advanced DNS Configuration

### Wildcard DNS

For multiple subdomains:

```
Type: A
Host: *
Value: 20.123.45.67
TTL: 3600
```

**Matches:**

- `anything.myapp.com`
- `api.myapp.com`
- `staging.myapp.com`
- `dev.myapp.com`

**Useful for:**

- Per-user subdomains: `user123.myapp.com`
- Environment subdomains: `dev.myapp.com`, `staging.myapp.com`
- Multi-tenant applications

**Ingress configuration:**

```yaml
spec:
  rules:
    - host: "*.myapp.com"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 3000
```

### Subdomain Structure

**Common patterns:**

```
myapp.com           → Main application
www.myapp.com       → Alias to main
api.myapp.com       → API endpoints
staging.myapp.com   → Staging environment
dev.myapp.com       → Development environment
admin.myapp.com     → Admin panel
docs.myapp.com      → Documentation
blog.myapp.com      → Blog
status.myapp.com    → Status page
```

**DNS records:**

```
# Main domain
Type: A, Host: @, Value: 20.123.45.67

# WWW
Type: CNAME, Host: www, Value: myapp.com

# API
Type: A, Host: api, Value: 20.123.45.67

# Staging (different cluster)
Type: A, Host: staging, Value: 20.123.45.68

# Development (different cluster)
Type: A, Host: dev, Value: 20.123.45.69

# Admin (same cluster, different Ingress path)
Type: A, Host: admin, Value: 20.123.45.67

# Blog (external service like Medium)
Type: CNAME, Host: blog, Value: custom-domain.medium.com
```

### Geographic DNS (Geo-routing)

**Azure Traffic Manager example:**

```bash
# Create Traffic Manager profile
az network traffic-manager profile create \
  --name myapp-traffic-manager \
  --resource-group rg-ecommerce-aks-dev \
  --routing-method Geographic \
  --unique-dns-name myapp-tm

# Add US endpoint
az network traffic-manager endpoint create \
  --name us-endpoint \
  --profile-name myapp-traffic-manager \
  --resource-group rg-ecommerce-aks-dev \
  --type externalEndpoints \
  --target 20.123.45.67 \
  --geo-mapping US

# Add EU endpoint
az network traffic-manager endpoint create \
  --name eu-endpoint \
  --profile-name myapp-traffic-manager \
  --resource-group rg-ecommerce-aks-dev \
  --type externalEndpoints \
  --target 52.123.45.67 \
  --geo-mapping EU
```

**DNS record:**

```
Type: CNAME
Host: @
Value: myapp-tm.trafficmanager.net
```

### DDoS Protection with DNS

**Using Cloudflare:**

1. Enable proxy (orange cloud)
2. Cloudflare provides DDoS protection
3. Your real IP is hidden

**Using Azure DDoS Protection:**

```bash
# Enable DDoS protection on Public IP
az network public-ip update \
  --resource-group rg-ecommerce-aks-dev \
  --name aks-public-ip \
  --ddos-protection-plan /subscriptions/.../ddosProtectionPlan
```

---

## Best Practices

### 1. Use Appropriate TTL Values

```
Planning changes: TTL = 300 (5 minutes)
Normal operation: TTL = 3600 (1 hour)
Stable production: TTL = 86400 (24 hours)
```

**Strategy:**

1. Lower TTL 24 hours before planned changes
2. Make changes
3. Monitor for 24 hours
4. Raise TTL back to normal

### 2. Always Have www Subdomain

```
# Both should work:
myapp.com
www.myapp.com

# Configure both:
Type: A, Host: @, Value: 20.123.45.67
Type: CNAME, Host: www, Value: myapp.com
```

### 3. Use DNS for Multiple Environments

```
prod.myapp.com    → Production cluster
staging.myapp.com → Staging cluster
dev.myapp.com     → Development cluster
```

### 4. Monitor DNS Resolution

```bash
# Create monitoring script
cat > check-dns.sh <<'EOF'
#!/bin/bash
DOMAIN="myapp.com"
EXPECTED_IP="20.123.45.67"

CURRENT_IP=$(dig +short $DOMAIN @8.8.8.8)

if [ "$CURRENT_IP" != "$EXPECTED_IP" ]; then
  echo "DNS mismatch! Expected: $EXPECTED_IP, Got: $CURRENT_IP"
  # Send alert
fi
EOF

# Run periodically with cron
*/5 * * * * /path/to/check-dns.sh
```

### 5. Document Your DNS Configuration

```markdown
# DNS Configuration for myapp.com

## Records

- Root (@): A → 20.123.45.67 (Production AKS)
- www: CNAME → myapp.com
- api: A → 20.123.45.67 (Same cluster)
- staging: A → 20.123.45.68 (Staging AKS)

## Nameservers

- ns1.provider.com
- ns2.provider.com

## TTL: 3600 seconds

## Last Updated: 2026-01-21

## Updated By: DevOps Team
```

### 6. Use Infrastructure as Code

**Terraform example:**

```hcl
resource "azurerm_dns_zone" "main" {
  name                = "myapp.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_dns_a_record" "root" {
  name                = "@"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 3600
  records             = ["20.123.45.67"]
}

resource "azurerm_dns_cname_record" "www" {
  name                = "www"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 3600
  record              = "myapp.com"
}
```

### 7. Security Considerations

**Enable DNSSEC (if supported):**

- Protects against DNS spoofing
- Not all registrars support it

**Use CAA records:**

```
Type: CAA
Host: @
Value: 0 issue "letsencrypt.org"
TTL: 3600
```

**Prevents unauthorized certificate issuance**

### 8. Regular Audits

```bash
# Monthly DNS audit
dig myapp.com ANY

# Check for:
# - Unexpected records
# - Old/unused records
# - Correct IP addresses
# - Appropriate TTL values
```

---

## Quick Reference

### Common Commands

```bash
# Check A record
dig A myapp.com

# Check with specific DNS server
dig @8.8.8.8 myapp.com

# Full trace
dig myapp.com +trace

# Check TTL
dig myapp.com | grep TTL

# Flush DNS cache (macOS)
sudo dscacheutil -flushcache

# Test HTTP
curl -I http://myapp.com

# Test HTTPS
curl -I https://myapp.com
```

### DNS Record Templates

**Root domain:**

```
Type: A
Host: @ (or blank)
Value: YOUR_INGRESS_IP
TTL: 3600
```

**WWW subdomain:**

```
Type: CNAME
Host: www
Value: myapp.com (or @)
TTL: 3600
```

**API subdomain:**

```
Type: A
Host: api
Value: YOUR_INGRESS_IP
TTL: 3600
```

---

## Checklist

### Initial Setup

- [ ] Purchase domain name
- [ ] Get Ingress external IP
- [ ] Log into DNS provider
- [ ] Create A record for root domain
- [ ] Create CNAME for www
- [ ] Set appropriate TTL (3600)
- [ ] Save changes
- [ ] Wait for propagation (30 min - 2 hours)
- [ ] Test with nslookup
- [ ] Test with curl
- [ ] Verify in browser

### SSL Setup (After DNS)

- [ ] DNS resolving correctly
- [ ] Install cert-manager
- [ ] Create ClusterIssuer
- [ ] Update Ingress with TLS
- [ ] Wait for certificate
- [ ] Test HTTPS
- [ ] Enable SSL redirect

### Maintenance

- [ ] Monitor DNS resolution monthly
- [ ] Check for unused records
- [ ] Verify IP addresses are current
- [ ] Review TTL settings
- [ ] Test failover procedures
- [ ] Update documentation

---

## Additional Resources

### Documentation

- **DNS RFC:** https://www.rfc-editor.org/rfc/rfc1035
- **DNS Best Practices:** https://www.icann.org/resources/pages/dnssec-what-is-it-why-important-2019-03-05-en

### Tools

- **DNS Checker:** https://dnschecker.org
- **What's My DNS:** https://www.whatsmydns.net
- **MX Toolbox:** https://mxtoolbox.com
- **dig web interface:** https://toolbox.googleapps.com/apps/dig/

### Learning

- **How DNS Works:** https://howdns.works
- **DNS Explained:** https://www.cloudflare.com/learning/dns/what-is-dns/

---

## Summary

1. **DNS translates** domain names to IP addresses
2. **A records** point domains to IPs
3. **CNAME records** create aliases
4. **TTL** controls cache duration
5. **Propagation** takes time (5 min - 48 hours)
6. **Test thoroughly** before going live
7. **Monitor** DNS health regularly
8. **Document** your configuration
9. **Use IaC** for production environments
10. **Plan changes** by lowering TTL first

**Key Formula:**

```
Domain Name + DNS Records + Ingress IP = Working Application
```

Good luck with your DNS setup! 🚀
