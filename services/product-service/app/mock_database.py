"""
Mock in-memory database for testing without PostgreSQL
"""
from typing import List, Optional, Dict
from uuid import UUID, uuid4
from datetime import datetime
import logging
from app.models import Product, ProductCreate, ProductUpdate

logger = logging.getLogger(__name__)


class MockDatabase:
    """In-memory mock database"""

    def __init__(self):
        self.products: Dict[UUID, Product] = {}
        logger.info("Using MOCK in-memory database")

    def init_db(self):
        """Initialize with mock data"""
        logger.info("Initializing mock database...")

        mock_products = [
            ("Laptop", "High-performance laptop", 999.99, "Electronics", 50),
            ("Mouse", "Wireless mouse", 29.99, "Electronics", 200),
            ("Keyboard", "Mechanical keyboard", 79.99, "Electronics", 150),
            ("Monitor", "27-inch 4K monitor", 399.99, "Electronics", 75),
            ("Headphones", "Noise-canceling headphones", 199.99, "Electronics", 100),
            ("Desk Chair", "Ergonomic office chair", 299.99, "Furniture", 30),
            ("Standing Desk", "Adjustable height desk", 499.99, "Furniture", 20),
            ("Notebook", "Spiral notebook pack", 9.99, "Stationery", 500),
            ("Pen Set", "Premium pen set", 19.99, "Stationery", 300),
            ("Backpack", "Laptop backpack", 59.99, "Accessories", 120),
        ]

        for name, desc, price, category, inventory in mock_products:
            product = Product(
                id=uuid4(),
                name=name,
                description=desc,
                price=price,
                category=category,
                inventory_count=inventory,
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )
            self.products[product.id] = product

        logger.info(f"Inserted {len(mock_products)} mock products")

    def get_products(self, limit: int = 100, offset: int = 0) -> List[Product]:
        """Get all products with pagination"""
        all_products = sorted(
            self.products.values(),
            key=lambda p: p.created_at,
            reverse=True
        )
        return all_products[offset:offset + limit]

    def get_product_by_id(self, product_id: UUID) -> Optional[Product]:
        """Get product by ID"""
        return self.products.get(product_id)

    def create_product(self, product: ProductCreate) -> Product:
        """Create a new product"""
        new_product = Product(
            id=uuid4(),
            name=product.name,
            description=product.description,
            price=product.price,
            category=product.category,
            inventory_count=product.inventory_count,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        self.products[new_product.id] = new_product
        logger.info(f"Created product {new_product.id}")
        return new_product

    def update_product(self, product_id: UUID, product_update: ProductUpdate) -> Optional[Product]:
        """Update a product"""
        product = self.products.get(product_id)
        if not product:
            return None

        # Update fields
        if product_update.name is not None:
            product.name = product_update.name
        if product_update.description is not None:
            product.description = product_update.description
        if product_update.price is not None:
            product.price = product_update.price
        if product_update.category is not None:
            product.category = product_update.category
        if product_update.inventory_count is not None:
            product.inventory_count = product_update.inventory_count

        product.updated_at = datetime.utcnow()
        logger.info(f"Updated product {product_id}")
        return product

    def delete_product(self, product_id: UUID) -> bool:
        """Delete a product"""
        if product_id in self.products:
            del self.products[product_id]
            logger.info(f"Deleted product {product_id}")
            return True
        return False

    def search_products(self, query: str) -> List[Product]:
        """Search products by name"""
        query_lower = query.lower()
        results = [
            product for product in self.products.values()
            if query_lower in product.name.lower() or
            (product.description and query_lower in product.description.lower())
        ]
        return sorted(results, key=lambda p: p.created_at, reverse=True)

    def health_check(self) -> bool:
        """Health check always returns True for mock"""
        return True
