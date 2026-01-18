# 1. Create directory

mkdir -p frontend-service/src/{app,components,services,contexts,types,utils}

# 2. Copy all files from artifacts above

# 3. Install dependencies

cd frontend-service
npm install

# 4. Start backend services first

cd ../user-service
python -m uvicorn app.main:app --port 8080 &

cd ../product-service
python -m uvicorn app.main:app --port 8081 &

# 5. Start frontend

cd ../frontend-service
npm run dev

# 6. Open browser

open http://localhost:3000

```

---

## Complete System Architecture
```

┌─────────────────────────────────────────────────────────────┐
│ USER BROWSER │
└───────────────────────┬─────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────┐
│ Frontend Service (Next.js) - Port 3000 │
│ │
│ Pages: Home, Products, Login, Register, Profile │
└───────────────────────┬─────────────────────────────────────┘
│
┌───────────────┼───────────────┐
│ │ │
▼ ▼ ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ User │ │ Product │ │ Future │
│ Service │ │ Service │ │ Services │
│ Port 8080 │ │ Port 8081 │ │ │
└──────────────┘ └──────────────┘ └──────────────┘
│ │
▼ ▼
PostgreSQL PostgreSQL
Redis Redis
RabbitMQ RabbitMQ
