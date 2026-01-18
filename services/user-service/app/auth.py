from jose import jwt
from datetime import datetime, timedelta
from passlib.context import CryptContext
from typing import Optional
from uuid import UUID
import logging
from app.config import settings
from app.models import TokenData, Token

logger = logging.getLogger(__name__)

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class AuthHandler:
    """Handles authentication and JWT tokens"""

    def __init__(self):
        self.secret = settings.JWT_SECRET
        self.algorithm = settings.JWT_ALGORITHM
        self.expiration_minutes = settings.JWT_EXPIRATION_MINUTES

    def hash_password(self, password: str) -> str:
        """Hash a password"""
        return pwd_context.hash(password)

    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        """Verify a password against its hash"""
        try:
            return pwd_context.verify(plain_password, hashed_password)
        except Exception as e:
            logger.error(f"Password verification error: {e}")
            return False

    def create_access_token(self, user_id: UUID, email: str) -> Token:
        """Create a JWT access token"""
        try:
            expires_at = datetime.utcnow() + timedelta(minutes=self.expiration_minutes)

            payload = {
                "user_id": str(user_id),
                "email": email,
                "exp": expires_at,
                "iat": datetime.utcnow()
            }

            token = jwt.encode(payload, self.secret, algorithm=self.algorithm)

            return Token(
                access_token=token,
                token_type="bearer",
                expires_in=self.expiration_minutes * 60  # Convert to seconds
            )
        except Exception as e:
            logger.error(f"Token creation error: {e}")
            raise

    def decode_token(self, token: str) -> Optional[TokenData]:
        """Decode and validate a JWT token"""
        try:
            payload = jwt.decode(token, self.secret,
                                 algorithms=[self.algorithm])

            user_id = UUID(payload.get("user_id"))
            email = payload.get("email")
            exp = datetime.fromtimestamp(payload.get("exp"))

            if not user_id or not email:
                return None

            return TokenData(user_id=user_id, email=email, exp=exp)

        except jwt.ExpiredSignatureError:
            logger.warning("Token has expired")
            return None
        except jwt.InvalidTokenError as e:
            logger.warning(f"Invalid token: {e}")
            return None
        except Exception as e:
            logger.error(f"Token decode error: {e}")
            return None

    def is_token_expired(self, token_data: TokenData) -> bool:
        """Check if token is expired"""
        return datetime.utcnow() > token_data.exp


# Global auth handler instance
auth_handler = AuthHandler()
