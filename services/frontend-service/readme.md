# Frontend Service

Modern React/Next.js 14 frontend for the microservices learning platform.

## Features

- ✅ **Next.js 14** with App Router
- ✅ **TypeScript** for type safety
- ✅ **Tailwind CSS** for styling
- ✅ **JWT Authentication** with User Service
- ✅ **Product Catalog** integration
- ✅ **Context API** for state management
- ✅ **Responsive Design**
- ✅ **Docker Support**

## Pages

- `/` - Home page
- `/products` - Product listing and search
- `/login` - User login
- `/register` - User registration
- `/profile` - User profile (protected)

## Tech Stack

- **Framework**: Next.js 14
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **HTTP Client**: Axios
- **State Management**: React Context API

## Quick Start

### Option 1: Development Mode

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Open browser
open http://localhost:3000
```

### Option 2: Docker

```bash
# Build image
docker build -t frontend-service .

# Run container
docker run -p 3000:3000 \
  -e NEXT_PUBLIC_USER_SERVICE_URL=http://localhost:8080 \
  -e NEXT_PUBLIC_PRODUCT_SERVICE_URL=http://localhost:8081 \
  frontend-service
```

### Option 3: With All Services

```bash
# From project root
docker-compose up -d

# Frontend available at http://localhost:3000
```

## Environment Variables

```bash
# User Service URL
NEXT_PUBLIC_USER_SERVICE_URL=http://localhost:8080

# Product Service URL
NEXT_PUBLIC_PRODUCT_SERVICE_URL=http://localhost:8081
```

## Project Structure

```
src/
├── app/                    # Next.js App Router pages
│   ├── layout.tsx         # Root layout
│   ├── page.tsx           # Home page
│   ├── login/
│   ├── register/
│   ├── products/
│   └── profile/
├── components/            # Reusable components
│   ├── Header.tsx
│   └── ProductCard.tsx
├── services/              # API clients
│   ├── api.ts
│   ├── userService.ts
│   └── productService.ts
├── contexts/              # React contexts
│   └── AuthContext.tsx
├── types/                 # TypeScript types
│   └── index.ts
└── utils/                 # Utility functions
    └── auth.ts
```

## API Integration

### User Service (Port 8080)

```typescript
// Login
await userService.login({ email, password });

// Register
await userService.register({ email, password, first_name, last_name });

// Get Profile
const user = await userService.getProfile();

// Logout
await userService.logout();
```

### Product Service (Port 8081)

```typescript
// Get all products
const products = await productService.getProducts();

// Search products
const results = await productService.searchProducts("laptop");

// Get single product
const product = await productService.getProduct(id);
```

## Authentication Flow

1. User registers/logs in via User Service
2. JWT token returned and stored in localStorage
3. Token automatically added to subsequent requests
4. Protected routes check authentication status
5. On logout, token is blacklisted and cleared

## Component Examples

### Using Auth Context

```typescript
'use client';

import { useAuth } from '@/contexts/AuthContext';

export default function MyComponent() {
  const { user, isAuthenticated, login, logout } = useAuth();

  if (!isAuthenticated) {
    return <div>Please login</div>;
  }

  return <div>Welcome, {user.first_name}!</div>;
}
```

### Calling APIs

```typescript
import { productService } from "@/services/productService";

async function loadProducts() {
  try {
    const products = await productService.getProducts();
    setProducts(products);
  } catch (error) {
    console.error("Failed to load products:", error);
  }
}
```

## Styling with Tailwind

```tsx
<button className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded">
  Click Me
</button>
```

## Building for Production

```bash
# Build
npm run build

# Start production server
npm start
```

## Docker Multi-Stage Build

The Dockerfile uses Next.js standalone output for optimal image size:

- **Build stage**: Compiles Next.js application
- **Runtime stage**: Minimal Node.js runtime
- **Result**: ~150MB image (vs 1GB+ without optimization)

## Testing

```bash
# Lint
npm run lint

# Type check
npx tsc --noEmit
```

## Integration with Backend Services

### Development (Direct URLs)

```typescript
// Services run on different ports
User Service: http://localhost:8080
Product Service: http://localhost:8081
```

### Production (Via Ingress)

```typescript
// All traffic goes through ingress
User Service: /api/users/*
Product Service: /api/products/*
```

## Test Accounts

Use these credentials to test (created by User Service):

```
Email: john.doe@example.com
Password: password123
```

## Common Tasks

### Add New Page

```bash
# Create new page
mkdir -p src/app/my-page
touch src/app/my-page/page.tsx
```

### Add New Component

```bash
# Create component
touch src/components/MyComponent.tsx
```

### Add New API Service

```bash
# Create service
touch src/services/myService.ts
```

## Troubleshooting

### Cannot connect to backend services

Make sure backend services are running:

```bash
# Check User Service
curl http://localhost:8080/healthz

# Check Product Service
curl http://localhost:8081/healthz
```

### Authentication not working

1. Check if User Service is running
2. Clear localStorage: `localStorage.clear()`
3. Check browser console for errors
4. Verify JWT token is being sent

### Styles not applying

```bash
# Rebuild Tailwind
npm run dev
```

## Performance Optimization

- ✅ Server-Side Rendering (SSR)
- ✅ Static Generation where possible
- ✅ Image optimization with Next.js Image
- ✅ Code splitting
- ✅ Lazy loading
- ✅ API response caching

## Security

- ✅ JWT tokens in localStorage
- ✅ Automatic token refresh
- ✅ Protected routes
- ✅ XSS protection
- ✅ CSRF protection via SameSite cookies (future)

## Future Enhancements

- [ ] Shopping cart functionality
- [ ] Order management
- [ ] Admin panel
- [ ] Real-time notifications
- [ ] Payment integration
- [ ] Product reviews
- [ ] Wishlist

## License

MIT - Learning project
