#!/usr/bin/env python3
"""
Simple test script for Product Service
Tests all major endpoints
"""
import requests
import json
import sys
from typing import Optional

# Configuration
BASE_URL = "http://localhost:8081"
COLORS = {
    "GREEN": "\033[92m",
    "RED": "\033[91m",
    "YELLOW": "\033[93m",
    "BLUE": "\033[94m",
    "RESET": "\033[0m"
}


def print_success(message: str):
    print(f"{COLORS['GREEN']}✓ {message}{COLORS['RESET']}")


def print_error(message: str):
    print(f"{COLORS['RED']}✗ {message}{COLORS['RESET']}")


def print_info(message: str):
    print(f"{COLORS['BLUE']}ℹ {message}{COLORS['RESET']}")


def print_warning(message: str):
    print(f"{COLORS['YELLOW']}⚠ {message}{COLORS['RESET']}")


def test_health_check():
    """Test health check endpoint"""
    print_info("Testing health check...")
    try:
        response = requests.get(f"{BASE_URL}/healthz", timeout=5)
        if response.status_code == 200:
            print_success(f"Health check passed: {response.json()['status']}")
            return True
        else:
            print_error(f"Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Health check failed: {e}")
        return False


def test_readiness_check():
    """Test readiness check endpoint"""
    print_info("Testing readiness check...")
    try:
        response = requests.get(f"{BASE_URL}/ready", timeout=5)
        data = response.json()
        print_success(f"Readiness check: {data['status']}")

        # Print dependency status
        deps = data.get('dependencies', {})
        for dep, status in deps.items():
            if status:
                print_success(f"  {dep}: healthy")
            else:
                print_warning(f"  {dep}: unavailable")

        return response.status_code == 200
    except Exception as e:
        print_error(f"Readiness check failed: {e}")
        return False


def test_get_products():
    """Test getting all products"""
    print_info("Testing GET /api/products...")
    try:
        response = requests.get(f"{BASE_URL}/api/products", timeout=5)
        if response.status_code == 200:
            products = response.json()
            print_success(f"Retrieved {len(products)} products")
            if products:
                print_info(
                    f"  Sample: {products[0]['name']} - ${products[0]['price']}")
            return products
        else:
            print_error(f"Failed to get products: {response.status_code}")
            return None
    except Exception as e:
        print_error(f"Failed to get products: {e}")
        return None


def test_get_product_by_id(product_id: str):
    """Test getting a single product"""
    print_info(f"Testing GET /api/products/{product_id[:8]}...")
    try:
        response = requests.get(
            f"{BASE_URL}/api/products/{product_id}", timeout=5)
        if response.status_code == 200:
            product = response.json()
            print_success(f"Retrieved product: {product['name']}")
            return product
        else:
            print_error(f"Failed to get product: {response.status_code}")
            return None
    except Exception as e:
        print_error(f"Failed to get product: {e}")
        return None


def test_create_product():
    """Test creating a new product"""
    print_info("Testing POST /api/products...")

    new_product = {
        "name": "Test Gaming Mouse",
        "description": "RGB gaming mouse with 16000 DPI",
        "price": 79.99,
        "category": "Electronics",
        "inventory_count": 50
    }

    try:
        response = requests.post(
            f"{BASE_URL}/api/products",
            json=new_product,
            timeout=5
        )
        if response.status_code == 201:
            product = response.json()
            print_success(
                f"Created product: {product['name']} (ID: {product['id'][:8]}...)")
            return product
        else:
            print_error(f"Failed to create product: {response.status_code}")
            return None
    except Exception as e:
        print_error(f"Failed to create product: {e}")
        return None


def test_update_product(product_id: str):
    """Test updating a product"""
    print_info(f"Testing PUT /api/products/{product_id[:8]}...")

    update_data = {
        "price": 69.99,
        "inventory_count": 75
    }

    try:
        response = requests.put(
            f"{BASE_URL}/api/products/{product_id}",
            json=update_data,
            timeout=5
        )
        if response.status_code == 200:
            product = response.json()
            print_success(
                f"Updated product: ${product['price']}, inventory: {product['inventory_count']}")
            return product
        else:
            print_error(f"Failed to update product: {response.status_code}")
            return None
    except Exception as e:
        print_error(f"Failed to update product: {e}")
        return None


def test_search_products(query: str = "laptop"):
    """Test searching products"""
    print_info(f"Testing GET /api/products/search?q={query}...")
    try:
        response = requests.get(
            f"{BASE_URL}/api/products/search?q={query}", timeout=5)
        if response.status_code == 200:
            products = response.json()
            print_success(f"Search returned {len(products)} results")
            for product in products[:3]:  # Show first 3
                print_info(f"  {product['name']} - ${product['price']}")
            return products
        else:
            print_error(f"Failed to search products: {response.status_code}")
            return None
    except Exception as e:
        print_error(f"Failed to search products: {e}")
        return None


def test_get_inventory(product_id: str):
    """Test getting inventory"""
    print_info(f"Testing GET /api/products/{product_id[:8]}/inventory...")
    try:
        response = requests.get(
            f"{BASE_URL}/api/products/{product_id}/inventory",
            timeout=5
        )
        if response.status_code == 200:
            data = response.json()
            print_success(f"Inventory count: {data['inventory_count']}")
            return data
        else:
            print_error(f"Failed to get inventory: {response.status_code}")
            return None
    except Exception as e:
        print_error(f"Failed to get inventory: {e}")
        return None


def test_delete_product(product_id: str):
    """Test deleting a product"""
    print_info(f"Testing DELETE /api/products/{product_id[:8]}...")
    try:
        response = requests.delete(
            f"{BASE_URL}/api/products/{product_id}", timeout=5)
        if response.status_code == 204:
            print_success("Product deleted successfully")
            return True
        else:
            print_error(f"Failed to delete product: {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Failed to delete product: {e}")
        return False


def test_metrics():
    """Test Prometheus metrics endpoint"""
    print_info("Testing GET /metrics...")
    try:
        response = requests.get(f"{BASE_URL}/metrics", timeout=5)
        if response.status_code == 200:
            metrics_text = response.text
            metric_count = len([line for line in metrics_text.split('\n')
                                if line and not line.startswith('#')])
            print_success(f"Metrics endpoint working ({metric_count} metrics)")
            return True
        else:
            print_error(f"Failed to get metrics: {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Failed to get metrics: {e}")
        return False


def test_cache_stats():
    """Test cache statistics endpoint"""
    print_info("Testing GET /debug/cache-stats...")
    try:
        response = requests.get(f"{BASE_URL}/debug/cache-stats", timeout=5)
        if response.status_code == 200:
            stats = response.json()
            print_success(f"Cache stats: {stats}")
            return True
        else:
            print_error(f"Failed to get cache stats: {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Failed to get cache stats: {e}")
        return False


def run_all_tests():
    """Run all tests"""
    print("\n" + "="*60)
    print("PRODUCT SERVICE TEST SUITE")
    print("="*60 + "\n")

    # Check if service is running
    print_info(f"Testing service at {BASE_URL}...")

    if not test_health_check():
        print_error("\nService is not running! Start it with:")
        print_info("  python -m uvicorn app.main:app --port 8081")
        print_info("  OR")
        print_info("  docker-compose up -d")
        return

    print()

    # Run tests
    test_readiness_check()
    print()

    # Get products
    products = test_get_products()
    if not products:
        print_error("Cannot continue tests without products")
        return

    product_id = products[0]['id']
    print()

    # Test single product
    test_get_product_by_id(product_id)
    print()

    # Test search
    test_search_products("laptop")
    print()

    # Test create
    new_product = test_create_product()
    if new_product:
        new_product_id = new_product['id']
        print()

        # Test update
        test_update_product(new_product_id)
        print()

        # Test inventory
        test_get_inventory(new_product_id)
        print()

        # Test delete
        test_delete_product(new_product_id)
        print()

    # Test monitoring endpoints
    test_metrics()
    print()

    test_cache_stats()
    print()

    print("="*60)
    print_success("All tests completed!")
    print("="*60 + "\n")


if __name__ == "__main__":
    try:
        run_all_tests()
    except KeyboardInterrupt:
        print_warning("\n\nTests interrupted by user")
        sys.exit(1)
