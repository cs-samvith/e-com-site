"""
Mock in-memory database for testing without PostgreSQL
"""
from typing import List, Optional, Dict
from uuid import UUID, uuid4
from datetime import datetime
import logging
from app.models import User, UserInDB, UserCreate, UserUpdate
from app.auth import auth_handler

logger = logging.getLogger(__name__)


class MockDatabase:
    """In-memory mock database"""

    def __init__(self):
        self.users: Dict[UUID, UserInDB] = {}
        self.users_by_email: Dict[str, UUID] = {}
        logger.info("Using MOCK in-memory database")

    def init_db(self):
        """Initialize with mock data"""
        logger.info("Initializing mock database...")

        # Create test users
        mock_users = [
            ("john.doe@example.com", "John", "Doe", "password123", "+1-555-0101"),
            ("jane.smith@example.com", "Jane",
             "Smith", "password123", "+1-555-0102"),
            ("bob.wilson@example.com", "Bob",
             "Wilson", "password123", "+1-555-0103"),
            ("alice.brown@example.com", "Alice", "Brown", "password123", None),
            ("charlie.davis@example.com", "Charlie", "Davis", "password123", None),
        ]

        for email, first_name, last_name, password, phone in mock_users:
            user_create = UserCreate(
                email=email,
                first_name=first_name,
                last_name=last_name,
                password=password,
                phone=phone
            )
            self.create_user(user_create)

        logger.info(f"Inserted {len(mock_users)} mock users")

    def get_users(self, limit: int = 100, offset: int = 0) -> List[User]:
        """Get all users (without passwords)"""
        all_users = sorted(
            self.users.values(),
            key=lambda u: u.created_at,
            reverse=True
        )

        # Convert to User (remove password_hash)
        users = [
            User(
                id=u.id,
                email=u.email,
                first_name=u.first_name,
                last_name=u.last_name,
                phone=u.phone,
                created_at=u.created_at,
                updated_at=u.updated_at
            )
            for u in all_users[offset:offset + limit]
        ]

        return users

    def get_user_by_id(self, user_id: UUID) -> Optional[User]:
        """Get user by ID (without password)"""
        user_in_db = self.users.get(user_id)
        if not user_in_db:
            return None

        return User(
            id=user_in_db.id,
            email=user_in_db.email,
            first_name=user_in_db.first_name,
            last_name=user_in_db.last_name,
            phone=user_in_db.phone,
            created_at=user_in_db.created_at,
            updated_at=user_in_db.updated_at
        )

    def get_user_by_email(self, email: str) -> Optional[UserInDB]:
        """Get user by email (with password hash - for authentication)"""
        user_id = self.users_by_email.get(email.lower())
        if user_id:
            return self.users.get(user_id)
        return None

    def create_user(self, user: UserCreate) -> User:
        """Create a new user"""
        # Check if email already exists
        if user.email.lower() in self.users_by_email:
            raise ValueError(f"User with email {user.email} already exists")

        # Hash password
        password_hash = auth_handler.hash_password(user.password)

        # Create user
        user_id = uuid4()
        now = datetime.utcnow()

        user_in_db = UserInDB(
            id=user_id,
            email=user.email,
            first_name=user.first_name,
            last_name=user.last_name,
            phone=user.phone,
            password_hash=password_hash,
            created_at=now,
            updated_at=now
        )

        self.users[user_id] = user_in_db
        self.users_by_email[user.email.lower()] = user_id

        logger.info(f"Created user {user_id} ({user.email})")

        # Return User (without password)
        return User(
            id=user_in_db.id,
            email=user_in_db.email,
            first_name=user_in_db.first_name,
            last_name=user_in_db.last_name,
            phone=user_in_db.phone,
            created_at=user_in_db.created_at,
            updated_at=user_in_db.updated_at
        )

    def update_user(self, user_id: UUID, user_update: UserUpdate) -> Optional[User]:
        """Update a user"""
        user = self.users.get(user_id)
        if not user:
            return None

        # Update fields
        if user_update.first_name is not None:
            user.first_name = user_update.first_name
        if user_update.last_name is not None:
            user.last_name = user_update.last_name
        if user_update.phone is not None:
            user.phone = user_update.phone

        user.updated_at = datetime.utcnow()

        logger.info(f"Updated user {user_id}")

        # Return User (without password)
        return User(
            id=user.id,
            email=user.email,
            first_name=user.first_name,
            last_name=user.last_name,
            phone=user.phone,
            created_at=user.created_at,
            updated_at=user.updated_at
        )

    def update_password(self, user_id: UUID, new_password: str) -> bool:
        """Update user password"""
        user = self.users.get(user_id)
        if not user:
            return False

        user.password_hash = auth_handler.hash_password(new_password)
        user.updated_at = datetime.utcnow()

        logger.info(f"Updated password for user {user_id}")
        return True

    def delete_user(self, user_id: UUID) -> bool:
        """Delete a user"""
        user = self.users.get(user_id)
        if not user:
            return False

        # Remove from email index
        self.users_by_email.pop(user.email.lower(), None)

        # Remove user
        del self.users[user_id]

        logger.info(f"Deleted user {user_id}")
        return True

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
        """Health check always returns True for mock"""
        return True
