# Custom Grafana Dashboards for E-Commerce

Complete guide to setting up and using custom Grafana dashboards tailored for e-commerce metrics.

## 📊 Table of Contents

1. [Dashboard Overview](#dashboard-overview)
2. [Quick Setup](#quick-setup)
3. [Metrics Available](#metrics-available)
4. [Dashboard Panels Explained](#dashboard-panels-explained)
5. [Instrumenting Your Services](#instrumenting-your-services)
6. [Creating Custom Panels](#creating-custom-panels)
7. [Alert Configuration](#alert-configuration)
8. [Best Practices](#best-practices)

---

## Dashboard Overview

### What's Included

**E-Commerce Overview Dashboard** - Main business dashboard showing:

- 📈 Total requests across all services
- 👥 Active users (approximation)
- ⚠️ Error rate percentage
- ⏱️ Average response time
- 🛍️ Product metrics (views, cart adds, searches)
- 👤 User metrics (registrations, logins, sessions)
- 💾 Database and cache performance
- 💰 Business KPIs (conversion funnel, revenue)
- 🏆 Top products
- ❌ Failed transactions

---

## Quick Setup

### Step 1: Deploy Monitoring Stack

```bash
# Deploy Prometheus and Grafana
gh workflow run monitoring-deploy.yml \
  --field environment=dev \
  --field stack=prometheus-grafana

# Or manually
kubectl apply -f kubernetes/monitoring/prometheus-stack.yaml
```

### Step 2: Access Grafana

```bash
# Get Grafana URL
GRAFANA_IP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Grafana URL: http://$GRAFANA_IP"

# Default credentials
# Username: admin
# Password: admin123 (⚠️ CHANGE THIS!)
```

### Step 3: Import Dashboard

**Option A: Via Grafana UI**

1. Login to Grafana
2. Click **+** → **Import**
3. Upload `kubernetes/monitoring/grafana-dashboards/ecommerce-overview.json`
4. Select Prometheus datasource
5. Click **Import**

**Option B: Auto-provision via ConfigMap**

```bash
# Apply the dashboard ConfigMap
kubectl apply -f kubernetes/monitoring/grafana-dashboard-configmap.yaml

# Restart Grafana to load new dashboard
kubectl rollout restart deployment/grafana -n monitoring
```

**Option C: Via API**

```bash
GRAFANA_URL="http://$GRAFANA_IP"
API_KEY="your-api-key"  # Create in Grafana UI: Configuration → API Keys

curl -X POST "$GRAFANA_URL/api/dashboards/db" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d @kubernetes/monitoring/grafana-dashboards/ecommerce-overview.json
```

### Step 4: Instrument Your Services

Add metrics to your Python/FastAPI services:

```bash
# Install Prometheus client
pip install prometheus-client

# Copy metrics modules to your services
cp services/product-service/app/metrics.py services/product-service/app/
cp services/user-service/app/metrics.py services/user-service/app/

# Update main.py with metrics integration
# See example in services/product-service/app/main.py
```

---

## Metrics Available

### Business Metrics

#### Product Service

```python
# Track these in your code
product_views_total                    # Counter - Product page views
products_added_to_cart_total          # Counter - Items added to cart
product_search_queries_total          # Counter - Search queries
product_inventory_level               # Gauge - Current inventory
product_current_price                 # Gauge - Current price
```

#### User Service

```python
user_registrations_total              # Counter - New registrations
user_login_attempts_total             # Counter - Login attempts
user_active_sessions                  # Gauge - Active sessions
user_sessions_created_total           # Counter - Sessions created
user_password_reset_requests_total    # Counter - Password resets
user_profile_updates_total            # Counter - Profile updates
jwt_tokens_issued_total               # Counter - JWT tokens issued
```

#### Checkout/Orders (Add to your services)

```python
checkout_initiated_total              # Counter - Checkouts started
orders_completed_total                # Counter - Completed orders
order_total_revenue                   # Counter - Total revenue
checkout_failed_total                 # Counter - Failed checkouts
```

### Technical Metrics

```python
# HTTP Metrics (auto-tracked via middleware)
http_requests_total                   # Counter - All HTTP requests
http_request_duration_seconds         # Histogram - Request latency

# Database Metrics
database_query_duration_seconds       # Histogram - Query performance
database_connections_active           # Gauge - Active connections
database_connections_idle             # Gauge - Idle connections

# Cache Metrics (Redis)
redis_cache_hits_total               # Counter - Cache hits
redis_cache_misses_total             # Counter - Cache misses
redis_operations_total               # Counter - Redis operations
redis_operation_duration_seconds     # Histogram - Operation latency

# Security Metrics
failed_login_attempts_by_ip          # Counter - Failed logins by IP
suspicious_activities_total          # Counter - Suspicious activities
rate_limit_exceeded_total            # Counter - Rate limit violations
```

---

## Dashboard Panels Explained

### Row 1: Key Performance Indicators (KPIs)

#### Total Requests

```promql
sum(rate(http_requests_total[5m])) * 300
```

Shows total requests across all services in the last 5 minutes.

**Thresholds:**

- 🟢 Green: < 1000 requests
- 🟡 Yellow: 1000-5000 requests
- 🔴 Red: > 5000 requests

#### Active Users

```promql
sum(rate(user_sessions_created_total[5m])) * 300
```

Approximates active users based on session creation rate.

#### Error Rate

```promql
(sum(rate(http_requests_total{status=~"5.."}[5m])) /
 sum(rate(http_requests_total[5m]))) * 100
```

Percentage of requests resulting in 5xx errors.

**Thresholds:**

- 🟢 Green: < 1%
- 🟡 Yellow: 1-5%
- 🔴 Red: > 5%

#### Average Response Time

```promql
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
) * 1000
```

95th percentile response time in milliseconds.

### Row 2: Request Trends

#### Request Rate by Service

Shows individual service request rates to identify which services are busiest.

#### Response Time Percentiles

Displays p50, p95, and p99 response times to understand latency distribution.

### Row 3: Product Metrics

#### Product Views

```promql
sum(rate(product_views_total[5m]))
```

Rate of product page views.

#### Products Added to Cart

```promql
sum(rate(products_added_to_cart_total[5m]))
```

Rate of add-to-cart actions.

#### Product Searches

```promql
sum(rate(product_search_queries_total[5m]))
```

Rate of search queries.

### Row 4: User Metrics

#### User Registrations

```promql
sum(rate(user_registrations_total[5m]))
```

New user registration rate.

#### Login Success vs Failed

```promql
sum(rate(user_login_attempts_total{status="success"}[5m]))
sum(rate(user_login_attempts_total{status="failed"}[5m]))
```

Compare successful and failed login attempts.

#### Active Sessions

```promql
sum(user_active_sessions)
```

Current number of active user sessions.

### Row 5: Database & Cache

#### Database Query Duration

```promql
histogram_quantile(0.95,
  sum(rate(database_query_duration_seconds_bucket[5m])) by (le, operation)
) * 1000
```

Database query performance by operation type.

#### Cache Hit Rate

```promql
(sum(rate(redis_cache_hits_total[5m])) /
 (sum(rate(redis_cache_hits_total[5m])) +
  sum(rate(redis_cache_misses_total[5m])))) * 100
```

Percentage of cache requests that hit.

**Thresholds:**

- 🔴 Red: < 70%
- 🟡 Yellow: 70-90%
- 🟢 Green: > 90%

### Row 6: Business KPIs

#### Conversion Funnel

Shows the customer journey:

1. Product Views
2. Added to Cart
3. Checkout Initiated
4. Orders Completed

Helps identify drop-off points.

#### Revenue Metrics

- Total revenue (last hour)
- Average order value

#### Top Products

Table showing most viewed products in the last hour.

#### Failed Transactions

Table showing checkout failures by reason.

---

## Instrumenting Your Services

### Product Service Example

```python
from fastapi import FastAPI
from .metrics import (
    track_product_view,
    track_add_to_cart,
    get_metrics
)

app = FastAPI()

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=get_metrics(), media_type="text/plain")

@app.get("/products/{product_id}")
async def get_product(product_id: str):
    # Your business logic
    product = get_product_from_db(product_id)

    # Track the view
    track_product_view(
        product_id=product.id,
        product_name=product.name,
        category=product.category
    )

    return product

@app.post("/cart/add")
async def add_to_cart(item: CartItem):
    # Your business logic

    # Track add to cart
    track_add_to_cart(
        product_id=item.product_id,
        product_name=item.product_name
    )

    return {"success": True}
```

### User Service Example

```python
from .metrics import (
    track_user_registration,
    track_login_attempt,
    track_session_creation
)

@app.post("/register")
async def register(user: UserCreate):
    # Your registration logic

    # Track registration
    track_user_registration(source="web")

    return {"user_id": new_user.id}

@app.post("/login")
async def login(credentials: LoginCredentials):
    # Your authentication logic
    success = authenticate(credentials)

    # Track login attempt
    track_login_attempt(success=success, method="email")

    if success:
        track_session_creation()

    return {"success": success}
```

### Add Prometheus Annotations to Deployments

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
        - name: product-service
          ports:
            - containerPort: 8080
              name: http
```

---

## Creating Custom Panels

### Example: Cart Abandonment Rate

1. Click **Add Panel** in Grafana
2. Add query:

```promql
(
  sum(increase(products_added_to_cart_total[1h])) -
  sum(increase(checkout_initiated_total[1h]))
) / sum(increase(products_added_to_cart_total[1h])) * 100
```

3. Panel settings:
   - Type: Stat
   - Unit: Percent (0-100)
   - Thresholds: 0 (green), 50 (yellow), 70 (red)

### Example: Revenue by Product Category

1. Add query:

```promql
sum(increase(order_total_revenue[1h])) by (product_category)
```

2. Panel settings:
   - Type: Pie Chart
   - Legend: Show values

### Example: Failed Login Attempts by Hour

1. Add query:

```promql
sum(increase(user_login_attempts_total{status="failed"}[1h]))
```

2. Panel settings:
   - Type: Time Series
   - Fill: 10
   - Alert threshold: > 100

---

## Alert Configuration

### Create Grafana Alerts

#### High Cart Abandonment Alert

1. Edit panel
2. Click **Alert** tab
3. Configure:
   - Condition: `WHEN last() OF query(A) IS ABOVE 70`
   - For: `5m`
   - Message: "Cart abandonment rate is {{value}}%"

#### Low Cache Hit Rate Alert

```yaml
Alert Rule:
  Name: Low Cache Hit Rate
  Condition: WHEN last() OF cache_hit_rate IS BELOW 70
  For: 10m
  Message: Cache hit rate dropped to {{value}}%
  Severity: Warning
```

#### Revenue Drop Alert

```yaml
Alert Rule:
  Name: Revenue Drop
  Condition: WHEN diff() OF revenue IS BELOW -1000
  For: 15m
  Message: Revenue dropped by ${{value}}
  Severity: Critical
```

---

## Best Practices

### 1. Metric Naming

- Use consistent prefixes: `product_`, `user_`, `order_`
- Use `_total` suffix for counters
- Use descriptive names: `products_added_to_cart_total` not `cart_adds`

### 2. Labels

- Keep cardinality low (< 1000 unique combinations)
- Avoid high-cardinality labels like user IDs or timestamps
- Use labels for filtering: `{status="success"}`, `{category="electronics"}`

### 3. Dashboard Organization

- Group related metrics in rows
- Use consistent colors across panels
- Add descriptions to panels
- Set appropriate time ranges

### 4. Performance

- Use `rate()` for counters, not `increase()` for graphs
- Use `histogram_quantile()` for percentiles
- Avoid too many queries per panel (< 5)
- Use dashboard variables for reusability

### 5. Alerts

- Set appropriate thresholds based on baseline
- Use `For` duration to avoid flapping
- Group related alerts
- Test alerts before deploying

---

## Troubleshooting

### Metrics Not Showing

**Check 1: Prometheus is scraping**

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Visit: http://localhost:9090/targets
# Look for your services - should show "UP"
```

**Check 2: Metrics endpoint works**

```bash
# Port forward your service
kubectl port-forward -n ecommerce <pod-name> 8080:8080

# Check metrics
curl http://localhost:8080/metrics
```

**Check 3: Annotations are correct**

```bash
kubectl get pods -n ecommerce -o yaml | grep -A 3 "prometheus.io"
```

### Dashboard Shows No Data

**Check 1: Prometheus datasource configured**

```
Configuration → Data Sources → Prometheus
URL should be: http://prometheus:9090
```

**Check 2: Time range**

- Ensure time range includes recent data
- Check "Last 5 minutes" to see if metrics are flowing

**Check 3: Query syntax**

- Test queries in Prometheus UI first
- Check metric names match exactly

### High Cardinality Warning

If you see warnings about high cardinality:

```python
# BAD - user_id creates too many unique metrics
user_actions_total.labels(user_id=user_id, action=action).inc()

# GOOD - aggregate by action type only
user_actions_total.labels(action=action).inc()
```

---

## Example Queries

### Business Analytics

**Conversion rate (view → cart → checkout → order):**

```promql
(sum(increase(orders_completed_total[1h])) /
 sum(increase(product_views_total[1h]))) * 100
```

**Average time between cart add and checkout:**

```promql
avg(checkout_initiated_timestamp - cart_add_timestamp)
```

**Most popular products (last 24h):**

```promql
topk(10, sum(increase(product_views_total[24h])) by (product_name))
```

**Revenue by hour:**

```promql
sum(increase(order_total_revenue[1h]))
```

### Technical Performance

**Slowest endpoints:**

```promql
topk(5, histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le, endpoint)
))
```

**Error rate by service:**

```promql
sum(rate(http_requests_total{status=~"5.."}[5m])) by (job) /
sum(rate(http_requests_total[5m])) by (job) * 100
```

**Database connection pool utilization:**

```promql
(database_connections_active / database_connections_max) * 100
```

---

## Summary

You now have:

- ✅ Custom e-commerce dashboard
- ✅ Business and technical metrics
- ✅ Instrumentation code for Python/FastAPI
- ✅ Alert configurations
- ✅ Best practices guide

**Next Steps:**

1. Deploy the dashboard
2. Instrument your services
3. Create custom alerts
4. Monitor your e-commerce platform!

Need help? Check troubleshooting or create an issue! 📊
