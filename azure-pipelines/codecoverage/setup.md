# Setup Guide: Code Coverage & Security Scanning

## Python FastAPI + React/Next.js Stack

## Overview

This guide will help you add code coverage and security scanning to:

- **Backend Services**: Python FastAPI (product-service, user-service)
- **Frontend Service**: React + TypeScript + Next.js (frontend-service)

## 📋 Prerequisites

- Python 3.11+
- Node.js 18.x+
- Azure DevOps pipeline configured
- Services already containerized

---

## 🔧 Step 1: Install Dependencies

### For Backend Services (Python FastAPI)

```bash
cd services/product-service  # or user-service

# Install testing dependencies
pip install pytest pytest-asyncio pytest-cov pytest-mock httpx

# Or add to requirements-dev.txt and install:
pip install -r requirements-dev.txt
```

**requirements-dev.txt:**

```
pytest==7.4.3
pytest-asyncio==0.21.1
pytest-cov==4.1.0
pytest-mock==3.12.0
httpx==0.25.2
black==23.12.1
flake8==7.0.0
mypy==1.7.1
```

### For Frontend Service (React + Next.js)

```bash
cd services/frontend-service

npm install --save-dev \
  jest@^29.7.0 \
  @types/jest@^29.5.11 \
  jest-environment-jsdom@^29.7.0 \
  @testing-library/react@^14.1.2 \
  @testing-library/jest-dom@^6.1.5 \
  @testing-library/user-event@^14.5.1 \
  jest-junit@^16.0.0
```

---

## 📝 Step 2: Add Configuration Files

### Python Services Configuration

**1. Create `pytest.ini`** in both `product-service` and `user-service`:

```ini
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*

addopts =
    -v
    --strict-markers
    --tb=short
    --cov=app
    --cov-report=html
    --cov-report=xml
    --cov-report=term-missing
    --cov-branch
    --cov-fail-under=80
    --junitxml=junit.xml

asyncio_mode = auto

markers =
    unit: Unit tests
    integration: Integration tests
```

**2. Create `conftest.py`** in `tests/` directory:

```python
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.database import Base, get_db

TEST_DATABASE_URL = "sqlite:///./test.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
```

**3. Optional: Create `Makefile`** for convenience:

```makefile
.PHONY: test coverage

test:
	pytest

coverage:
	pytest --cov=app --cov-report=html --cov-report=xml

test-ci:
	pytest --cov=app --cov-report=xml --junitxml=junit.xml -v
```

### Frontend Service Configuration

**1. Create `jest.config.js`:**

```javascript
const nextJest = require("next/jest");

const createJestConfig = nextJest({ dir: "./" });

const customJestConfig = {
  testEnvironment: "jsdom",
  setupFilesAfterEnv: ["<rootDir>/jest.setup.js"],
  moduleNameMapper: {
    "^@/(.*)$": "<rootDir>/src/$1",
    "^.+\\.module\\.(css|sass|scss)$": "identity-obj-proxy",
    "^.+\\.(css|sass|scss)$": "<rootDir>/__mocks__/styleMock.js",
    "^.+\\.(jpg|jpeg|png|gif|webp|svg)$": "<rootDir>/__mocks__/fileMock.js",
  },
  collectCoverage: true,
  coverageDirectory: "coverage",
  coverageReporters: ["text", "lcov", "html", "json", "cobertura"],
  collectCoverageFrom: [
    "src/**/*.{js,jsx,ts,tsx}",
    "!src/**/*.d.ts",
    "!src/**/*.test.{js,jsx,ts,tsx}",
    "!src/pages/_app.tsx",
    "!src/pages/_document.tsx",
  ],
  coverageThreshold: {
    global: { branches: 70, functions: 70, lines: 70, statements: 70 },
  },
  reporters: [
    "default",
    [
      "jest-junit",
      {
        outputDirectory: "./coverage",
        outputName: "junit.xml",
      },
    ],
  ],
};

module.exports = createJestConfig(customJestConfig);
```

**2. Create `jest.setup.js`:**

```javascript
import "@testing-library/jest-dom";

jest.mock("next/router", () => ({
  useRouter: jest.fn(),
}));
```

**3. Create mock files:**

`__mocks__/styleMock.js`:

```javascript
module.exports = {};
```

`__mocks__/fileMock.js`:

```javascript
module.exports = "test-file-stub";
```

**4. Update `package.json` scripts:**

```json
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "test:ci": "jest --coverage --ci"
  }
}
```

---

## ✅ Step 3: Write Your First Tests

### Python FastAPI Test Example

**tests/test_products.py:**

```python
import pytest
from fastapi import status

def test_create_product(client):
    """Test creating a new product."""
    product_data = {
        "name": "Test Product",
        "price": 99.99,
        "stock": 100
    }

    response = client.post("/api/products", json=product_data)

    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["name"] == product_data["name"]
    assert "id" in data

def test_get_products(client):
    """Test getting all products."""
    response = client.get("/api/products")

    assert response.status_code == status.HTTP_200_OK
    assert isinstance(response.json(), list)

def test_get_product_not_found(client):
    """Test 404 for non-existent product."""
    response = client.get("/api/products/99999")

    assert response.status_code == status.HTTP_404_NOT_FOUND
```

### React/Next.js Test Example

**src/components/ProductCard.test.tsx:**

```typescript
import { render, screen } from '@testing-library/react';
import ProductCard from './ProductCard';

describe('ProductCard', () => {
  const mockProduct = {
    id: 1,
    name: 'Test Product',
    price: 99.99,
  };

  it('renders product information', () => {
    render(<ProductCard product={mockProduct} />);

    expect(screen.getByText('Test Product')).toBeInTheDocument();
    expect(screen.getByText('$99.99')).toBeInTheDocument();
  });
});
```

---

## 📁 Expected Project Structure

```
services/
├── product-service/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py
│   │   ├── models.py
│   │   ├── routers/
│   │   └── database.py
│   ├── tests/
│   │   ├── __init__.py
│   │   ├── conftest.py
│   │   ├── test_products.py
│   │   └── test_crud.py
│   ├── pytest.ini          # ⭐ NEW
│   ├── requirements.txt
│   ├── requirements-dev.txt # ⭐ NEW
│   ├── Makefile            # ⭐ OPTIONAL
│   └── Dockerfile
│
├── user-service/
│   ├── app/
│   ├── tests/
│   ├── pytest.ini          # ⭐ NEW
│   ├── requirements.txt
│   ├── requirements-dev.txt # ⭐ NEW
│   └── Dockerfile
│
└── frontend-service/
    ├── src/
    │   ├── components/
    │   │   └── *.test.tsx   # ⭐ NEW
    │   └── pages/
    ├── __mocks__/           # ⭐ NEW
    │   ├── styleMock.js
    │   └── fileMock.js
    ├── jest.config.js       # ⭐ NEW
    ├── jest.setup.js        # ⭐ NEW
    ├── package.json
    └── Dockerfile
```

---

## 🧪 Step 4: Test Locally

### Python Services

```bash
cd services/product-service

# Run tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Or use Makefile
make coverage

# View coverage report
open htmlcov/index.html  # macOS
xdg-open htmlcov/index.html  # Linux
```

### Frontend Service

```bash
cd services/frontend-service

# Run tests
npm test

# Run with coverage
npm run test:coverage

# View coverage report
open coverage/index.html
```

---

## 🔄 Step 5: Update Azure DevOps Pipeline

Replace your existing `azure-pipelines.yml` with the enhanced version that includes:

✅ **Python Test Stage** - pytest with coverage for FastAPI services
✅ **Node.js Test Stage** - Jest with coverage for React/Next.js
✅ **Build Stage** - Only runs if tests pass
✅ **Security Scan Stage** - Trivy scans for all images
✅ **Publish Stage** - Publishes all artifacts

### Key Pipeline Features:

1. **Separate test jobs** for Python and Node.js services
2. **Coverage threshold enforcement** (default 80%)
3. **Caching** for pip and npm packages
4. **Parallel execution** for faster builds
5. **Comprehensive reporting** in Azure DevOps

---

## 📊 Understanding Coverage Reports

### Python Coverage (pytest-cov)

After running tests, you'll see:

```
---------- coverage: platform linux, python 3.11 -----------
Name                    Stmts   Miss Branch BrPart  Cover
---------------------------------------------------------
app/__init__.py             0      0      0      0   100%
app/main.py                15      0      4      0   100%
app/models.py              25      2      0      0    92%
app/routers/products.py    45      3      8      2    89%
---------------------------------------------------------
TOTAL                     105      5     12      2    93%
```

### React Coverage (Jest)

```
----------------------|---------|----------|---------|---------|
File                  | % Stmts | % Branch | % Funcs | % Lines |
----------------------|---------|----------|---------|---------|
All files             |   85.5  |   82.3   |   88.2  |   85.1  |
 components           |   92.1  |   87.5   |   95.0  |   91.8  |
  ProductCard.tsx     |   95.2  |   90.0   |  100.0  |   95.0  |
 utils                |   78.9  |   75.0   |   80.0  |   78.5  |
----------------------|---------|----------|---------|---------|
```

---

## 🐛 Common Issues & Solutions

### Python Issues

**Issue:** `ModuleNotFoundError: No module named 'app'`
**Solution:** Make sure you're running pytest from the service root directory

**Issue:** Database errors during tests
**Solution:** Use SQLite in-memory for tests: `sqlite:///./test.db`

**Issue:** Async tests failing
**Solution:** Make sure `pytest-asyncio` is installed and `asyncio_mode = auto` in pytest.ini

### Frontend Issues

**Issue:** `Cannot find module 'next/router'`
**Solution:** Check `jest.setup.js` has proper mocks

**Issue:** CSS import errors
**Solution:** Verify `__mocks__/styleMock.js` exists and jest.config.js has correct moduleNameMapper

---

## 🎯 Best Practices

### For Python FastAPI

1. **Test API endpoints** - Use TestClient for synchronous, AsyncClient for async
2. **Mock external services** - Use `pytest-mock` for Redis, RabbitMQ, etc.
3. **Test database operations** - Use test database, clean up after each test
4. **Use fixtures** - Create reusable fixtures in conftest.py
5. **Mark tests** - Use `@pytest.mark.unit` and `@pytest.mark.integration`

### For React/Next.js

1. **Test user interactions** - Use `@testing-library/user-event`
2. **Test components in isolation** - Mock API calls
3. **Test accessibility** - Use `getByRole` queries
4. **Snapshot tests sparingly** - Only for stable UI
5. **Mock Next.js features** - Router, Image, etc.

---

## 📈 Coverage Goals

| Service Type      | Minimum | Good | Excellent |
| ----------------- | ------- | ---- | --------- |
| Backend (FastAPI) | 80%     | 85%  | 90%+      |
| Frontend (React)  | 70%     | 80%  | 85%+      |

**Focus on:**

- API endpoints (routers)
- Business logic (services, CRUD)
- Critical utilities

**Less important:**

- Config files
- Database models (basic)
- UI components (test integration instead)

---

## 🚀 Running in CI/CD

Your pipeline now automatically:

1. ✅ Installs Python 3.11 and Node.js 18
2. ✅ Caches dependencies (pip/npm)
3. ✅ Runs pytest for Python services
4. ✅ Runs Jest for frontend service
5. ✅ Enforces coverage thresholds
6. ✅ Publishes coverage reports
7. ✅ Scans Docker images with Trivy
8. ✅ Fails build if tests fail

---

## 📚 Additional Resources

**Python Testing:**

- [pytest documentation](https://docs.pytest.org/)
- [FastAPI Testing](https://fastapi.tiangolo.com/tutorial/testing/)
- [pytest-cov](https://pytest-cov.readthedocs.io/)

**React Testing:**

- [Testing Library](https://testing-library.com/react)
- [Jest Documentation](https://jestjs.io/)
- [Next.js Testing](https://nextjs.org/docs/testing)

**Security:**

- [Trivy Documentation](https://trivy.dev/)

---

## ✅ Checklist

- [ ] Install pytest and testing deps for Python services
- [ ] Install Jest and testing deps for frontend
- [ ] Create pytest.ini and conftest.py
- [ ] Create jest.config.js and jest.setup.js
- [ ] Write first test for each service
- [ ] Run tests locally successfully
- [ ] Update Azure pipeline
- [ ] Push and verify pipeline runs
- [ ] Review coverage reports
- [ ] Review security scan results

---

## 🆘 Quick Commands Reference

```bash
# Python services
cd services/product-service
pip install -r requirements-dev.txt
pytest --cov=app --cov-report=html
open htmlcov/index.html

# Frontend service
cd services/frontend-service
npm install
npm run test:coverage
open coverage/index.html

# Run specific test
pytest tests/test_products.py::test_create_product
npm test -- ProductCard.test.tsx
```
