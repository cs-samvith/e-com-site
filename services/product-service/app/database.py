import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
from typing import List, Optional
import logging
from uuid import UUID
from app.config import settings
from app.models import Product, ProductCreate, ProductUpdate

logger = logging.getLogger(__name__)


class Database:
    """PostgreSQL database handler"""
    
    def __init__(self):
        self.connection_string = (
            f"host={settings.DB_HOST} "
            f"port={settings.DB_PORT} "
            f"dbname={settings.DB_NAME} "
            f"user={settings.DB_USER} "
            f"password={settings.DB_PASSWORD}"
        )
    
    @contextmanager
    def get_connection(self):
        """Get database connection context manager"""
        conn = None
        try:
            conn = psycopg2.connect(self.connection_string)
            yield conn
            conn.commit()
        except Exception as e:
            if conn:
                conn.rollback()
            logger.error(f"Database error: {e}")
            raise
        finally:
            if conn:
                conn.close()
    
    def init_db(self):
        """Initialize database schema"""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        CREATE TABLE IF NOT EXISTS products (
                            id UUID PRIMARY KEY,
                            name VARCHAR(200) NOT NULL,
                            description TEXT,
                            price DECIMAL(10, 2) NOT NULL,
                            category VARCHAR(100) NOT NULL,
                            inventory_count INTEGER DEFAULT 0,
                            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                        )
                    """)
                    
                    # Create index on category
                    cur.execute("""
                        CREATE INDEX IF NOT EXISTS idx_products_category 
                        ON products(category)
                    """)
                    
                    # Create index on name for search
                    cur.execute("""
                        CREATE INDEX IF NOT EXISTS idx_products_name 
                        ON products(name)
                    """)
                    
            logger.info("Database initialized successfully")
            
            # Insert mock data if table is empty
            self._insert_mock_data()
            
        except Exception as e:
            logger.error(f"Failed to initialize database: {e}")
            raise
    
    def _insert_mock_data(self):
        """Insert mock product data"""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cur:
                    # Check if data exists
                    cur.execute("SELECT COUNT(*) FROM products")
                    count = cur.fetchone()[0]
                    
                    if count == 0:
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
                            cur.execute("""
                                INSERT INTO products 
                                (id, name, description, price, category, inventory_count)
                                VALUES (gen_random_uuid(), %s, %s, %s, %s, %s)
                            """, (name, desc, price, category, inventory))
                        
                        logger.info(f"Inserted {len(mock_products)} mock products")
        except Exception as e:
            logger.error(f"Failed to insert mock data: {e}")
    
    def get_products(self, limit: int = 100, offset: int = 0) -> List[Product]:
        """Get all products with pagination"""
        try:
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("""
                        SELECT * FROM products 
                        ORDER BY created_at DESC
                        LIMIT %s OFFSET %s
                    """, (limit, offset))
                    
                    rows = cur.fetchall()
                    return [Product(**row) for row in rows]
        except Exception as e:
            logger.error(f"Failed to get products: {e}")
            return []
    
    def get_product_by_id(self, product_id: UUID) -> Optional[Product]:
        """Get product by ID"""
        try:
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("SELECT * FROM products WHERE id = %s", (str(product_id),))
                    row = cur.fetchone()
                    return Product(**row) if row else None
        except Exception as e:
            logger.error(f"Failed to get product {product_id}: {e}")
            return None
    
    def create_product(self, product: ProductCreate) -> Product:
        """Create a new product"""
        try:
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("""
                        INSERT INTO products 
                        (id, name, description, price, category, inventory_count)
                        VALUES (gen_random_uuid(), %s, %s, %s, %s, %s)
                        RETURNING *
                    """, (
                        product.name,
                        product.description,
                        product.price,
                        product.category,
                        product.inventory_count
                    ))
                    
                    row = cur.fetchone()
                    return Product(**row)
        except Exception as e:
            logger.error(f"Failed to create product: {e}")
            raise
    
    def update_product(self, product_id: UUID, product_update: ProductUpdate) -> Optional[Product]:
        """Update a product"""
        try:
            # Build dynamic update query
            update_fields = []
            values = []
            
            if product_update.name is not None:
                update_fields.append("name = %s")
                values.append(product_update.name)
            
            if product_update.description is not None:
                update_fields.append("description = %s")
                values.append(product_update.description)
            
            if product_update.price is not None:
                update_fields.append("price = %s")
                values.append(product_update.price)
            
            if product_update.category is not None:
                update_fields.append("category = %s")
                values.append(product_update.category)
            
            if product_update.inventory_count is not None:
                update_fields.append("inventory_count = %s")
                values.append(product_update.inventory_count)
            
            if not update_fields:
                return self.get_product_by_id(product_id)
            
            update_fields.append("updated_at = CURRENT_TIMESTAMP")
            values.append(str(product_id))
            
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    query = f"""
                        UPDATE products 
                        SET {', '.join(update_fields)}
                        WHERE id = %s
                        RETURNING *
                    """
                    cur.execute(query, values)
                    row = cur.fetchone()
                    return Product(**row) if row else None
        except Exception as e:
            logger.error(f"Failed to update product {product_id}: {e}")
            raise
    
    def delete_product(self, product_id: UUID) -> bool:
        """Delete a product"""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("DELETE FROM products WHERE id = %s", (str(product_id),))
                    return cur.rowcount > 0
        except Exception as e:
            logger.error(f"Failed to delete product {product_id}: {e}")
            return False
    
    def search_products(self, query: str) -> List[Product]:
        """Search products by name"""
        try:
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("""
                        SELECT * FROM products 
                        WHERE name ILIKE %s OR description ILIKE %s
                        ORDER BY created_at DESC
                        LIMIT 50
                    """, (f"%{query}%", f"%{query}%"))
                    
                    rows = cur.fetchall()
                    return [Product(**row) for row in rows]
        except Exception as e:
            logger.error(f"Failed to search products: {e}")
            return []
    
    def health_check(self) -> bool:
        """Check database health"""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT 1")
                    return True
        except Exception:
            return False


# Global database instance
db = Database()
