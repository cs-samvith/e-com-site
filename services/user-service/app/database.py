import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
from typing import List, Optional
import logging
from uuid import UUID
from app.config import settings
from app.models import User, UserInDB, UserCreate, UserUpdate
from app.auth import auth_handler

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
                    # Create users table
                    cur.execute("""
                        CREATE TABLE IF NOT EXISTS users (
                            id UUID PRIMARY KEY,
                            email VARCHAR(255) UNIQUE NOT NULL,
                            password_hash VARCHAR(255) NOT NULL,
                            first_name VARCHAR(100) NOT NULL,
                            last_name VARCHAR(100) NOT NULL,
                            phone VARCHAR(20),
                            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                        )
                    """)

                    # Create index on email
                    cur.execute("""
                        CREATE INDEX IF NOT EXISTS idx_users_email 
                        ON users(email)
                    """)

            logger.info("Database initialized successfully")

            # Insert mock data if table is empty
            self._insert_mock_data()

        except Exception as e:
            logger.error(f"Failed to initialize database: {e}")
            raise

    def _insert_mock_data(self):
        """Insert mock user data"""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cur:
                    # Check if data exists
                    cur.execute("SELECT COUNT(*) FROM users")
                    count = cur.fetchone()[0]

                    if count == 0:
                        mock_users = [
                            ("john.doe@example.com", "John",
                             "Doe", "password123", "+1-555-0101"),
                            ("jane.smith@example.com", "Jane",
                             "Smith", "password123", "+1-555-0102"),
                            ("bob.wilson@example.com", "Bob",
                             "Wilson", "password123", "+1-555-0103"),
                            ("alice.brown@example.com", "Alice",
                             "Brown", "password123", None),
                            ("charlie.davis@example.com", "Charlie",
                             "Davis", "password123", None),
                        ]

                        for email, first_name, last_name, password, phone in mock_users:
                            password_hash = auth_handler.hash_password(
                                password)
                            cur.execute("""
                                INSERT INTO users 
                                (id, email, password_hash, first_name, last_name, phone)
                                VALUES (gen_random_uuid(), %s, %s, %s, %s, %s)
                            """, (email, password_hash, first_name, last_name, phone))

                        logger.info(f"Inserted {len(mock_users)} mock users")
        except Exception as e:
            logger.error(f"Failed to insert mock data: {e}")

    def get_users(self, limit: int = 100, offset: int = 0) -> List[User]:
        """Get all users (without passwords)"""
        try:
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("""
                        SELECT id, email, first_name, last_name, phone, 
                               created_at, updated_at
                        FROM users 
                        ORDER BY created_at DESC
                        LIMIT %s OFFSET %s
                    """, (limit, offset))

                    rows = cur.fetchall()
                    return [User(**row) for row in rows]
        except Exception as e:
            logger.error(f"Failed to get users: {e}")
            return []

    def get_user_by_id(self, user_id: UUID) -> Optional[User]:
        """Get user by ID (without password)"""
        try:
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("""
                        SELECT id, email, first_name, last_name, phone,
                               created_at, updated_at
                        FROM users WHERE id = %s
                    """, (str(user_id),))
                    row = cur.fetchone()
                    return User(**row) if row else None
        except Exception as e:
            logger.error(f"Failed to get user {user_id}: {e}")
            return None

    def get_user_by_email(self, email: str) -> Optional[UserInDB]:
        """Get user by email (with password hash - for authentication)"""
        try:
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("""
                        SELECT id, email, password_hash, first_name, last_name, 
                               phone, created_at, updated_at
                        FROM users WHERE LOWER(email) = LOWER(%s)
                    """, (email,))
                    row = cur.fetchone()
                    return UserInDB(**row) if row else None
        except Exception as e:
            logger.error(f"Failed to get user by email {email}: {e}")
            return None

    def create_user(self, user: UserCreate) -> User:
        """Create a new user"""
        try:
            # Hash password
            password_hash = auth_handler.hash_password(user.password)

            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("""
                        INSERT INTO users 
                        (id, email, password_hash, first_name, last_name, phone)
                        VALUES (gen_random_uuid(), %s, %s, %s, %s, %s)
                        RETURNING id, email, first_name, last_name, phone,
                                  created_at, updated_at
                    """, (
                        user.email,
                        password_hash,
                        user.first_name,
                        user.last_name,
                        user.phone
                    ))

                    row = cur.fetchone()
                    return User(**row)
        except psycopg2.errors.UniqueViolation:
            raise ValueError(f"User with email {user.email} already exists")
        except Exception as e:
            logger.error(f"Failed to create user: {e}")
            raise

    def update_user(self, user_id: UUID, user_update: UserUpdate) -> Optional[User]:
        """Update a user"""
        try:
            update_fields = []
            values = []

            if user_update.first_name is not None:
                update_fields.append("first_name = %s")
                values.append(user_update.first_name)

            if user_update.last_name is not None:
                update_fields.append("last_name = %s")
                values.append(user_update.last_name)

            if user_update.phone is not None:
                update_fields.append("phone = %s")
                values.append(user_update.phone)

            if not update_fields:
                return self.get_user_by_id(user_id)

            update_fields.append("updated_at = CURRENT_TIMESTAMP")
            values.append(str(user_id))

            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    query = f"""
                        UPDATE users 
                        SET {', '.join(update_fields)}
                        WHERE id = %s
                        RETURNING id, email, first_name, last_name, phone,
                                  created_at, updated_at
                    """
                    cur.execute(query, values)
                    row = cur.fetchone()
                    return User(**row) if row else None
        except Exception as e:
            logger.error(f"Failed to update user {user_id}: {e}")
            raise

    def update_password(self, user_id: UUID, new_password: str) -> bool:
        """Update user password"""
        try:
            password_hash = auth_handler.hash_password(new_password)

            with self.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        UPDATE users 
                        SET password_hash = %s, updated_at = CURRENT_TIMESTAMP
                        WHERE id = %s
                    """, (password_hash, str(user_id)))
                    return cur.rowcount > 0
        except Exception as e:
            logger.error(f"Failed to update password for user {user_id}: {e}")
            return False

    def delete_user(self, user_id: UUID) -> bool:
        """Delete a user"""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("DELETE FROM users WHERE id = %s",
                                (str(user_id),))
                    return cur.rowcount > 0
        except Exception as e:
            logger.error(f"Failed to delete user {user_id}: {e}")
            return False

    def authenticate_user(self, email: str, password: str) -> Optional[UserInDB]:
        """Authenticate user with email and password"""
        user = self.get_user_by_email(email)
        if not user:
            logger.warning(f"Authentication failed: user {email} not found")
            return None

        if not auth_handler.verify_password(password, user.password_hash):
            logger.warning(
                f"Authentication failed: invalid password for {email}")
            return None

        logger.info(f"User {email} authenticated successfully")
        return user

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
