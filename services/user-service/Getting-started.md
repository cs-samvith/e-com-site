# Getting Started with User Service

## 🚀 Quick Start (3 Steps)

### Step 1: Setup

```bash
cd C:\mygit\e-com-site\services\user-service

# Create virtual environment
python -m venv venv

# Activate
venv\Scripts\activate.bat

# Install dependencies
pip install -r requirements.txt
```

### Step 2: Run

```bash
# Run in mock mode (no dependencies needed)
python -m uvicorn app.main:app --reload --port 8080

# OR use helper script
run-mock.bat
```

### Step 3: Test

Open browser: http://localhost:8080/docs

---

## 🧪 Test Authentication Flow

### Via Swagger UI (Easiest!)

1. **Go to:** http://localhost:8080/docs

2. **Login:**
   - Find `POST /api/users/login`
   - Click "Try it out"
   - Use test account:
     ```json
     {
       "email": "john.doe@example.com",
       "password": "password123"
     }
     ```
   - Click "Execute"
   - Copy the `access_token` from response

3. **Authorize:**
   - Click "Authorize" button (🔒 at top right)
   - Paste the token (just the token, no "Bearer")
   - Click "Authorize" then "Close"

4. **Test Protected Endpoints:**
   - Try `GET /api/users/profile`
   - Try `GET /api/users` (list all users)
   - All will work with your token! ✅

---

### Via curl

```bash
# 1. Login
curl -X POST http://localhost:8080/api/users/login ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"john.doe@example.com\",\"password\":\"password123\"}"

# 2. Copy access_token from response

# 3. Get profile (replace YOUR_TOKEN)
curl http://localhost:8080/api/users/profile ^
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## 📋 Mock Test Accounts

All accounts have password: `password123`

| Email                     | Name          |
| ------------------------- | ------------- |
| john.doe@example.com      | John Doe      |
| jane.smith@example.com    | Jane Smith    |
| bob.wilson@example.com    | Bob Wilson    |
| alice.brown@example.com   | Alice Brown   |
| charlie.davis@example.com | Charlie Davis |

---

## 🔑 Authentication Explained

### How JWT Works

```
1. User logs in with email/password
   ↓
2. Service verifies credentials
   ↓
3. Service generates JWT token (expires in 24 hours)
   ↓
4. User receives token
   ↓
5. User includes token in subsequent requests
   Header: Authorization: Bearer <token>
   ↓
6. Service validates token and returns data
```

### What's in the Token?

```json
{
  "user_id": "f0014205-acec-47b2-83f5-f2d11ca42f9b",
  "email": "john.doe@example.com",
  "exp": 1737201220,
  "iat": 1737114820
}
```

- `user_id`: User's unique ID
- `email`: User's email
- `exp`: Expiration timestamp (24 hours from creation)
- `iat`: Issued at timestamp

---

## 🔐 Security Features

### Password Hashing

- Uses **bcrypt** with 12 rounds
- Passwords never stored in plain text
- Verify password on login

### JWT Tokens

- Signed with **HS256** algorithm
- Secret key: `JWT_SECRET` (change in production!)
- Expires after 24 hours (configurable)

### Token Blacklisting

- Logout blacklists the token
- Blacklisted tokens rejected even if not expired
- Stored in Redis (or skipped if Redis unavailable)

---

## 🧪 Complete Test Script

Create `test-auth.bat`:

```batch
@echo off
echo ========================================
echo Testing User Service Authentication
echo ========================================
echo.

echo [1/5] Health check...
curl http://localhost:8080/healthz
echo.
echo.

echo [2/5] Login with test account...
curl -X POST http://localhost:8080/api/users/login -H "Content-Type: application/json" -d "{\"email\":\"john.doe@example.com\",\"password\":\"password123\"}" > token.json
echo.
type token.json
echo.
echo.

echo [3/5] Copy the access_token from above
echo Paste it here (without quotes):
set /p TOKEN=Token:
echo.

echo [4/5] Getting user profile...
curl http://localhost:8080/api/users/profile -H "Authorization: Bearer %TOKEN%"
echo.
echo.

echo [5/5] Logout...
curl -X POST http://localhost:8080/api/users/logout -H "Authorization: Bearer %TOKEN%"
echo.
echo.

echo ========================================
echo Test Complete!
echo ========================================
pause
```

---

## 🐛 Common Issues

### "ModuleNotFoundError: No module named 'jwt'"

**Fix:** Update `app/auth.py` line 1:

```python
from jose import jwt  # Correct
# NOT: import jwt
```

### "passlib.handlers.bcrypt - WARNING"

This warning is harmless. Password hashing still works correctly.

### Swagger authorization not working

1. Make sure you clicked "Authorize" button
2. Paste ONLY the token (no "Bearer" prefix)
3. Token must be valid (not expired, not logged out)

---

## 📊 Integration with Product Service

Both services can work together:

```bash
# Terminal 1: User Service
cd services\user-service
venv\Scripts\activate.bat
python -m uvicorn app.main:app --reload --port 8080

# Terminal 2: Product Service
cd services\product-service
venv\Scripts\activate.bat
python -m uvicorn app.main:app --reload --port 8081

# Test flow:
# 1. Login to get token (User Service)
# 2. Use token to access products (Product Service - if auth enabled)
```

---

## ✅ Success Checklist

- [ ] Service starts without errors
- [ ] Can access http://localhost:8080/healthz
- [ ] Can login with test account
- [ ] Receive JWT token
- [ ] Can access `/api/users/profile` with token
- [ ] Swagger UI works with authorization

If all checked, you're ready! 🚀

---

## 🚀 Next Steps

- ✅ User Service running
- ⏭️ Create Frontend Service (React UI)
- ⏭️ Run all services together with Podman
- ⏭️ Create Kubernetes manifests
- ⏭️ Deploy to K8s cluster

Ready to continue? 🎯
