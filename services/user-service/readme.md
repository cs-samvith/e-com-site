# User Service

A simple microservice for user authentication and management, designed to demonstrate Kubernetes concepts.

## Features

- **User Registration & Authentication**
- **JWT Token-based Authentication**
- **Password Hashing** with bcrypt
- **Session Management** via Redis
- **PostgreSQL** for data persistence (optional - falls back to in-memory)
- **Redis** for sessions and token blacklisting (optional)
- **RabbitMQ** publisher for user events (optional)
- **Prometheus** metrics for monitoring
- **Health checks** for Kubernetes probes
- **Graceful degradation** - works without any dependencies!

## Quick Start (No Dependencies Required!)

```bash
# Install minimal dependencies
pip install fastapi uvicorn pydantic pydantic-settings pydantic[email] passlib[bcrypt] python-jose[cryptography] python-multipart prometheus-client python-json-logger

# Run the service
python -m uvicorn app.main:app --reload --port 8080

# Test it
curl http://localhost:8080/healthz
```

## API Endpoints

### Authentication

| Method | Endpoint              | Description              |
| ------ | --------------------- | ------------------------ |
| POST   | `/api/users/register` | Register new user        |
| POST   | `/api/users/login`    | Login (get JWT token)    |
| POST   | `/api/users/logout`   | Logout (blacklist token) |

### User Management (Requires Authentication)

| Method | Endpoint              | Description              |
| ------ | --------------------- | ------------------------ |
| GET    | `/api/users/profile`  | Get current user profile |
| PUT    | `/api/users/profile`  | Update profile           |
| PUT    | `/api/users/password` | Change password          |
| GET    | `/api/users`          | List all users (admin)   |
| GET    | `/api/users/{id}`     | Get user by ID           |

### Health & Monitoring

| Method | Endpoint             | Description        |
| ------ | -------------------- | ------------------ |
| GET    | `/healthz`           | Liveness probe     |
| GET    | `/ready`             | Readiness probe    |
| GET    | `/metrics`           | Prometheus metrics |
| GET    | `/debug/cache-stats` | Cache statistics   |

## API Examples

### 1. Register New User

```bash
curl -X POST http://localhost:8080/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "securepass123",
    "first_name": "Test",
    "last_name": "User",
    "phone": "+1-555-1234"
  }'
```

Response:

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "email": "test@example.com",
  "first_name": "Test",
  "last_name": "User",
  "phone": "+1-555-1234",
  "created_at": "2026-01-17T15:30:00Z",
  "updated_at": "2026-01-17T15:30:00Z"
}
```

### 2. Login

```bash
curl -X POST http://localhost:8080/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "securepass123"
  }'
```

Response:

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 86400
}
```

### 3. Get Profile (Authenticated)

```bash
# Save token from login response
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

curl http://localhost:8080/api/users/profile \
  -H "Authorization: Bearer $TOKEN"
```

### 4. Update Profile

```bash
curl -X PUT http://localhost:8080/api/users/profile \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Updated",
    "last_name": "Name",
    "phone": "+1-555-9999"
  }'
```

### 5. Change Password

```bash
curl -X PUT http://localhost:8080/api/users/password \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "old_password": "securepass123",
    "new_password": "newsecurepass456"
  }'
```

### 6. Logout

```bash
curl -X POST http://localhost:8080/api/users/logout \
  -H "Authorization: Bearer $TOKEN"
```

## Running Options

### Option 1: Standalone (No Dependencies) ⚡

```bash
pip install fastapi uvicorn pydantic pydantic-settings pydantic[email] passlib[bcrypt] python-jose[cryptography] python-multipart prometheus-client python-json-logger

python -m uvicorn app.main:app --reload --port 8080
```

### Option 2: With Docker Compose (Full Stack) 🚀

```bash
docker-compose up -d

# View logs
docker-compose logs -f user-service

# Stop
docker-compose down
```

### Option 3: With PostgreSQL Only

```bash
# Start PostgreSQL
docker run -d --name user-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=users_db \
  -p 5433:5432 \
  postgres:15

# Install dependencies
pip install -r requirements.txt

# Run
export DB_HOST=localhost
export DB_PORT=5433
python -m uvicorn app.main:app --reload --port 8080
```

## Mock Data

On first startup, the service automatically creates 5 test users:

| Email                     | Password    | Name          |
| ------------------------- | ----------- | ------------- |
| john.doe@example.com      | password123 | John Doe      |
| jane.smith@example.com    | password123 | Jane Smith    |
| bob.wilson@example.com    | password123 | Bob Wilson    |
| alice.brown@example.com   | password123 | Alice Brown   |
| charlie.davis@example.com | password123 | Charlie Davis |

**Note:** Change these passwords in production!

## Authentication Flow

```
1. User Registration:
   POST /api/users/register
   → Password hashed with bcrypt
   → User stored in database
   → Event published: user.created

2. User Login:
   POST /api/users/login
   → Verify email & password
   → Generate JWT token (24h expiry)
   → Create session in Redis
   → Return token to client
   → Event published: user.login

3. Authenticated Request:
   GET /api/users/profile
   Header: Authorization: Bearer <token>
   → Validate JWT token
   → Check if token blacklisted
   → Get user from database
   → Return user data

4. User Logout:
   POST /api/users/logout
   → Blacklist JWT token in Redis
   → Event published: user.logout
```

## JWT Token Structure

```json
{
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "email": "test@example.com",
  "exp": 1737134400,
  "iat": 1737048000
}
```

## Events Published to RabbitMQ

### user.created

```json
{
  "event": "user.created",
  "timestamp": "2026-01-17T15:30:00Z",
  "data": {
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "test@example.com",
    "first_name": "Test",
    "last_name": "User"
  }
}
```

### user.login

```json
{
  "event": "user.login",
  "timestamp": "2026-01-17T15:30:00Z",
  "data": {
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "test@example.com"
  }
}
```

### user.logout

```json
{
  "event": "user.logout",
  "timestamp": "2026-01-17T15:30:00Z",
  "data": {
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "test@example.com"
  }
}
```

## Environment Variables

See `.env.example` for all configuration options.

Key variables:

- `JWT_SECRET` - Secret key for JWT signing (change in production!)
- `JWT_EXPIRATION_MINUTES` - Token expiry time (default: 1440 = 24h)
- `SESSION_TTL` - Redis session TTL in seconds (default: 86400 = 24h)
- `BCRYPT_ROUNDS` - Password hashing rounds (default: 12)

## Security Notes

- Passwords are hashed using bcrypt with 12 rounds
- JWT tokens are signed with HS256 algorithm
- Tokens can be blacklisted on logout
- Sessions stored in Redis with TTL
- Change `JWT_SECRET` in production!
- Use HTTPS in production
- Implement rate limiting for login attempts (TODO)

## Testing with curl

Complete workflow:

```bash
# 1. Register
curl -X POST http://localhost:8080/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@test.com","password":"test1234","first_name":"Demo","last_name":"User"}'

# 2. Login and save token
TOKEN=$(curl -s -X POST http://localhost:8080/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@test.com","password":"test1234"}' \
  | jq -r '.access_token')

echo "Token: $TOKEN"

# 3. Get profile
curl http://localhost:8080/api/users/profile \
  -H "Authorization: Bearer $TOKEN"

# 4. Update profile
curl -X PUT http://localhost:8080/api/users/profile \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"first_name":"Updated"}'

# 5. Logout
curl -X POST http://localhost:8080/api/users/logout \
  -H "Authorization: Bearer $TOKEN"

# 6. Try to use token again (should fail)
curl http://localhost:8080/api/users/profile \
  -H "Authorization: Bearer $TOKEN"
```

## Prometheus Metrics

- `user_service_requests_total` - Total requests by endpoint and status
- `user_service_request_duration_seconds` - Request latency histogram

## Architecture

```
Client Request (with JWT token)
    ↓
FastAPI (validates token)
    ↓
    ├─→ Redis (check token blacklist)
    ├─→ Database (get user data)
    └─→ RabbitMQ (publish events)
    ↓
Response
```

## Integration with Product Service

Both services can run together:

```bash
# Product Service on port 8081
# User Service on port 8080

# User registers
curl -X POST http://localhost:8080/api/users/register ...

# User logs in and gets token
TOKEN=$(curl -X POST http://localhost:8080/api/users/login ...)

# User accesses products (if Product Service has auth)
curl http://localhost:8081/api/products \
  -H "Authorization: Bearer $TOKEN"
```

## Next Steps

- ✅ User Service created
- ⏭️ Frontend Service (React UI)
- ⏭️ API Gateway (route /api/users to User Service)
- ⏭️ Kubernetes manifests
- ⏭️ Service mesh (mTLS between services)
- ⏭️ Observability stack

## License

MIT - For learning purposes
