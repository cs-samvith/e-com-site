# ===================================================
# PYTHON FASTAPI SERVICES (product-service & user-service)
# ===================================================

# requirements.txt - Production dependencies
fastapi == 0.109.0
uvicorn[standard] == 0.27.0
pydantic == 2.5.3
pydantic-settings == 2.1.0
sqlalchemy == 2.0.25
alembic == 1.13.1
psycopg2-binary == 2.9.9
redis == 5.0.1
python-jose[cryptography] == 3.3.0
passlib[bcrypt] == 1.7.4
python-multipart == 0.0.6
aio-pika == 9.3.1

# requirements-dev.txt - Development & Testing dependencies
# Testing
pytest == 7.4.3
pytest-asyncio == 0.21.1
pytest-cov == 4.1.0
pytest-mock == 3.12.0
httpx == 0.25.2

# Code quality
black == 23.12.1
flake8 == 7.0.0
mypy == 1.7.1
isort == 5.13.2

---

# Makefile (Optional but recommended)
# Place in: services/product-service/Makefile
#           services/user-service/Makefile

.PHONY: install test coverage lint format clean

install:
    pip install - r requirements.txt
    pip install - r requirements-dev.txt

test:
    pytest

coverage:
    pytest - -cov = app - -cov-report = html - -cov-report = xml - -cov-report = term

test-ci:
    pytest - -cov = app - -cov-report = xml - -junitxml = junit.xml - v

lint:
    flake8 app tests
    mypy app

format:
    black app tests
    isort app tests

clean:
    rm - rf .pytest_cache
    rm - rf htmlcov
    rm - rf .coverage
    rm - f coverage.xml
    rm - f junit.xml
    find . -type d - name __pycache__ - exec rm - rf {} +
    find . -type f - name "*.pyc" - delete

---

# Commands for Python services
# Run tests:
make test
# or
pytest

# Run with coverage:
make coverage
# or
pytest - -cov = app - -cov-report = html

# Format code:
make format

# Lint code:
make lint


# ===================================================
# FRONTEND SERVICE (React + TypeScript + Next.js)
# ===================================================

# package.json
{
    "name": "frontend-service",
    "version": "1.0.0",
    "private": true,
    "scripts": {
        "dev": "next dev",
        "build": "next build",
        "start": "next start",
        "lint": "next lint",
        "test": "jest",
        "test:watch": "jest --watch",
        "test:coverage": "jest --coverage",
        "test:ci": "jest --coverage --ci --reporters=default --reporters=jest-junit",
        "type-check": "tsc --noEmit"
    },
    "dependencies": {
        "next": "14.0.4",
        "react": "18.2.0",
        "react-dom": "18.2.0",
        "axios": "1.6.5",
        "swr": "2.2.4"
    },
    "devDependencies": {
        "@types/jest": "^29.5.11",
        "@types/node": "^20.10.6",
        "@types/react": "^18.2.46",
        "@types/react-dom": "^18.2.18",
        "@testing-library/jest-dom": "^6.1.5",
        "@testing-library/react": "^14.1.2",
        "@testing-library/user-event": "^14.5.1",
        "jest": "^29.7.0",
        "jest-environment-jsdom": "^29.7.0",
        "jest-junit": "^16.0.0",
        "typescript": "^5.3.3",
        "eslint": "^8.56.0",
        "eslint-config-next": "14.0.4"
    }
}

---

# Commands for frontend service
# Install dependencies:
npm install

# Run tests:
npm test

# Run with coverage:
npm run test: coverage

# Run in watch mode:
npm run test: watch

# Type check:
npm run type-check


# ===================================================
# INSTALLATION COMMANDS
# ===================================================

# For Python services (product-service, user-service):
cd services/product-service
python - m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install - r requirements.txt
pip install - r requirements-dev.txt

# For frontend service:
cd services/frontend-service
npm install

---

# Quick test to verify setup:

# Python services:
cd services/product-service
pytest - -version  # Should show pytest version
pytest - v  # Run all tests

# Frontend:
cd services/frontend-service
npm test  # Run all tests
