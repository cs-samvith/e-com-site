# ==============================================
# pytest.ini - Configuration for pytest
# Place in: services/product-service/pytest.ini
#           services/user-service/pytest.ini
# ==============================================

[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*

# Code coverage settings
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

# Async support
asyncio_mode = auto

# Markers for organizing tests
markers =
    unit: Unit tests
    integration: Integration tests
    slow: Slow running tests
    smoke: Smoke tests

# Coverage configuration
[coverage:run]
source = app
omit =
    */tests/*
    */test_*.py
    */__init__.py
    */config.py
    */main.py

[coverage:report]
precision = 2
show_missing = True
skip_covered = False

exclude_lines =
    pragma: no cover
    def __repr__
    raise AssertionError
    raise NotImplementedError
    if __name__ == .__main__.:
    if TYPE_CHECKING:
    @abstractmethod


# ==============================================
# conftest.py - Pytest fixtures and configuration
# Place in: services/product-service/conftest.py
#           services/user-service/conftest.py
# ==============================================

import pytest
import asyncio
from typing import AsyncGenerator, Generator
from fastapi.testclient import TestClient
from httpx import AsyncClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.database import Base, get_db
from app.config import settings

# Test database URL
TEST_DATABASE_URL = "sqlite:///./test.db"

# Create test engine
engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="session")
def event_loop():
    """Create an event loop for the entire test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="function")
def db_session() -> Generator:
    """Create a fresh database session for each test."""
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session) -> Generator:
    """Create a test client with dependency override."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass
    
    app.dependency_overrides[get_db] = override_get_db
    
    with TestClient(app) as test_client:
        yield test_client
    
    app.dependency_overrides.clear()


@pytest.fixture(scope="function")
async def async_client(db_session) -> AsyncGenerator:
    """Create an async test client."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass
    
    app.dependency_overrides[get_db] = override_get_db
    
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac
    
    app.dependency_overrides.clear()


@pytest.fixture
def sample_product():
    """Fixture for sample product data."""
    return {
        "name": "Test Product",
        "description": "Test Description",
        "price": 99.99,
        "stock": 100
    }


@pytest.fixture
def sample_user():
    """Fixture for sample user data."""
    return {
        "email": "test@example.com",
        "username": "testuser",
        "password": "testpassword123"
    }


@pytest.fixture
def auth_headers():
    """Fixture for authentication headers."""
    # Mock JWT token for testing
    token = "test_token_12345"
    return {"Authorization": f"Bearer {token}"}


# ==============================================
# requirements-dev.txt - Development dependencies
# Place in: services/product-service/requirements-dev.txt
#           services/user-service/requirements-dev.txt
# ==============================================

# Testing
pytest==7.4.3
pytest-asyncio==0.21.1
pytest-cov==4.1.0
pytest-mock==3.12.0
httpx==0.25.2

# Code quality
black==23.12.1
flake8==7.0.0
mypy==1.7.1
isort==5.13.2
pylint==3.0.3

# Type stubs
types-requests==2.31.0.10


# ==============================================
# Example Test File Structure
# ==============================================

"""
services/product-service/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── models.py
│   ├── schemas.py
│   ├── crud.py
│   ├── routers/
│   │   ├── __init__.py
│   │   └── products.py
│   └── database.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── test_products.py
│   ├── test_crud.py
│   └── test_models.py
├── pytest.ini
├── requirements.txt
├── requirements-dev.txt
└── Dockerfile
"""


# ==============================================
# Example: tests/test_products.py
# ==============================================

import pytest
from fastapi import status

@pytest.mark.unit
def test_create_product(client, sample_product):
    """Test creating a new product."""
    response = client.post("/api/products", json=sample_product)
    
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["name"] == sample_product["name"]
    assert data["price"] == sample_product["price"]
    assert "id" in data


@pytest.mark.unit
def test_get_product_by_id(client, sample_product):
    """Test retrieving a product by ID."""
    # Create a product first
    create_response = client.post("/api/products", json=sample_product)
    product_id = create_response.json()["id"]
    
    # Get the product
    response = client.get(f"/api/products/{product_id}")
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["id"] == product_id
    assert data["name"] == sample_product["name"]


@pytest.mark.unit
def test_get_product_not_found(client):
    """Test retrieving a non-existent product."""
    response = client.get("/api/products/99999")
    
    assert response.status_code == status.HTTP_404_NOT_FOUND


@pytest.mark.unit
def test_get_all_products(client, sample_product):
    """Test retrieving all products."""
    # Create multiple products
    client.post("/api/products", json=sample_product)
    client.post("/api/products", json={**sample_product, "name": "Product 2"})
    
    response = client.get("/api/products")
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert len(data) >= 2


@pytest.mark.unit
def test_update_product(client, sample_product):
    """Test updating a product."""
    # Create a product
    create_response = client.post("/api/products", json=sample_product)
    product_id = create_response.json()["id"]
    
    # Update the product
    updated_data = {**sample_product, "price": 149.99}
    response = client.put(f"/api/products/{product_id}", json=updated_data)
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["price"] == 149.99


@pytest.mark.unit
def test_delete_product(client, sample_product):
    """Test deleting a product."""
    # Create a product
    create_response = client.post("/api/products", json=sample_product)
    product_id = create_response.json()["id"]
    
    # Delete the product
    response = client.delete(f"/api/products/{product_id}")
    
    assert response.status_code == status.HTTP_204_NO_CONTENT
    
    # Verify it's deleted
    get_response = client.get(f"/api/products/{product_id}")
    assert get_response.status_code == status.HTTP_404_NOT_FOUND


@pytest.mark.unit
def test_create_product_invalid_data(client):
    """Test creating a product with invalid data."""
    invalid_product = {
        "name": "",  # Empty name
        "price": -10  # Negative price
    }
    
    response = client.post("/api/products", json=invalid_product)
    
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


@pytest.mark.integration
@pytest.mark.asyncio
async def test_async_create_product(async_client, sample_product):
    """Test creating a product using async client."""
    response = await async_client.post("/api/products", json=sample_product)
    
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["name"] == sample_product["name"]


# ==============================================
# Example: tests/test_crud.py
# ==============================================

import pytest
from app.crud import (
    create_product,
    get_product,
    get_products,
    update_product,
    delete_product
)
from app.schemas import ProductCreate

@pytest.mark.unit
def test_crud_create_product(db_session, sample_product):
    """Test CRUD create operation."""
    product_data = ProductCreate(**sample_product)
    product = create_product(db_session, product_data)
    
    assert product.id is not None
    assert product.name == sample_product["name"]
    assert product.price == sample_product["price"]


@pytest.mark.unit
def test_crud_get_product(db_session, sample_product):
    """Test CRUD get operation."""
    product_data = ProductCreate(**sample_product)
    created_product = create_product(db_session, product_data)
    
    retrieved_product = get_product(db_session, created_product.id)
    
    assert retrieved_product is not None
    assert retrieved_product.id == created_product.id
    assert retrieved_product.name == created_product.name


@pytest.mark.unit
def test_crud_get_products(db_session, sample_product):
    """Test CRUD get all operation."""
    # Create multiple products
    for i in range(3):
        product_data = ProductCreate(**{**sample_product, "name": f"Product {i}"})
        create_product(db_session, product_data)
    
    products = get_products(db_session)
    
    assert len(products) == 3


@pytest.mark.unit
def test_crud_update_product(db_session, sample_product):
    """Test CRUD update operation."""
    product_data = ProductCreate(**sample_product)
    created_product = create_product(db_session, product_data)
    
    updated_data = ProductCreate(**{**sample_product, "price": 199.99})
    updated_product = update_product(db_session, created_product.id, updated_data)
    
    assert updated_product.price == 199.99


@pytest.mark.unit
def test_crud_delete_product(db_session, sample_product):
    """Test CRUD delete operation."""
    product_data = ProductCreate(**sample_product)
    created_product = create_product(db_session, product_data)
    
    result = delete_product(db_session, created_product.id)
    
    assert result is True
    assert get_product(db_session, created_product.id) is None