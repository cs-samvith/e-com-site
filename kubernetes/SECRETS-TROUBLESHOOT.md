# 1. Check if secret exists

kubectl get secret database-secrets -n ecommerce

# 2. List all keys in the secret

kubectl get secret database-secrets -n ecommerce -o jsonpath='{.data}' | jq 'keys'

# 3. Check POSTGRES_PASSWORD value (base64 encoded)

kubectl get secret database-secrets -n ecommerce -o jsonpath='{.data.POSTGRES_PASSWORD}'

# 4. Decode the password to see actual value

kubectl get secret database-secrets -n ecommerce -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
echo

# Should show your password (not empty!)

# Delete and recreate the secret

kubectl delete secret database-secrets -n ecommerce

# Create with proper values

kubectl create secret generic database-secrets \
 --from-literal=POSTGRES_USER=postgres \
 --from-literal=POSTGRES_PASSWORD=postgres123 \
 --from-literal=POSTGRES_HOST=postgres-service \
 --from-literal=POSTGRES_PORT=5432 \
 --from-literal=PRODUCT_DB_NAME=products_db \
 --from-literal=PRODUCT_DB_USER=postgres \
 --from-literal=PRODUCT_DB_PASSWORD=postgres123 \
 --from-literal=USER_DB_NAME=users_db \
 --from-literal=USER_DB_USER=postgres \
 --from-literal=USER_DB_PASSWORD=postgres123 \
 --from-literal=REDIS_HOST=redis-service \
 --from-literal=REDIS_PORT=6379 \
 --from-literal=RABBITMQ_HOST=rabbitmq-service \
 --from-literal=RABBITMQ_PORT=5672 \
 --from-literal=RABBITMQ_USER=guest \
 --from-literal=RABBITMQ_PASSWORD=guest \
 -n ecommerce

# Verify

kubectl get secret database-secrets -n ecommerce -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
echo

# Restart PostgreSQL

kubectl delete pod postgres-0 -n ecommerce

# Verify

kubectl get secret database-secrets -n ecommerce -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
echo

# Restart PostgreSQL

kubectl delete pod postgres-0 -n ecommerce
