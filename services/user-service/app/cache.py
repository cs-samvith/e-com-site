import redis
import json
import logging
from typing import Optional
from uuid import UUID
from app.config import settings
from app.models import Session

logger = logging.getLogger(__name__)


class Cache:
    """Redis cache handler for sessions and tokens"""

    def __init__(self):
        try:
            self.client = redis.Redis(
                host=settings.REDIS_HOST,
                port=settings.REDIS_PORT,
                password=settings.REDIS_PASSWORD,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5
            )
            # Test connection
            self.client.ping()
            logger.info("Redis connection established")
        except Exception as e:
            logger.warning(f"Redis connection failed: {e}. Cache disabled.")
            self.client = None

    def store_session(self, session: Session) -> bool:
        """Store user session"""
        if not self.client:
            return False

        try:
            key = f"session:{session.session_id}"
            session_dict = {
                "session_id": session.session_id,
                "user_id": str(session.user_id),
                "email": session.email,
                "created_at": session.created_at.isoformat(),
                "expires_at": session.expires_at.isoformat()
            }

            data = json.dumps(session_dict)
            self.client.setex(key, settings.SESSION_TTL, data)

            logger.info(
                f"Stored session {session.session_id} for user {session.user_id}")
            return True
        except Exception as e:
            logger.error(f"Failed to store session: {e}")
            return False

    def get_session(self, session_id: str) -> Optional[Session]:
        """Get user session"""
        if not self.client:
            return None

        try:
            key = f"session:{session_id}"
            data = self.client.get(key)

            if data:
                session_dict = json.loads(data)
                from datetime import datetime
                return Session(
                    session_id=session_dict["session_id"],
                    user_id=UUID(session_dict["user_id"]),
                    email=session_dict["email"],
                    created_at=datetime.fromisoformat(
                        session_dict["created_at"]),
                    expires_at=datetime.fromisoformat(
                        session_dict["expires_at"])
                )

            return None
        except Exception as e:
            logger.error(f"Failed to get session: {e}")
            return None

    def delete_session(self, session_id: str) -> bool:
        """Delete user session (logout)"""
        if not self.client:
            return False

        try:
            key = f"session:{session_id}"
            deleted = self.client.delete(key)

            if deleted:
                logger.info(f"Deleted session {session_id}")
            return bool(deleted)
        except Exception as e:
            logger.error(f"Failed to delete session: {e}")
            return False

    def blacklist_token(self, token: str, ttl: int) -> bool:
        """Blacklist a JWT token (for logout)"""
        if not self.client:
            return False

        try:
            key = f"blacklist:{token}"
            self.client.setex(key, ttl, "1")
            logger.info(f"Blacklisted token")
            return True
        except Exception as e:
            logger.error(f"Failed to blacklist token: {e}")
            return False

    def is_token_blacklisted(self, token: str) -> bool:
        """Check if token is blacklisted"""
        if not self.client:
            return False

        try:
            key = f"blacklist:{token}"
            return bool(self.client.exists(key))
        except Exception as e:
            logger.error(f"Failed to check token blacklist: {e}")
            return False

    def get_cache_stats(self) -> dict:
        """Get cache statistics"""
        if not self.client:
            return {"status": "disabled"}

        try:
            info = self.client.info("stats")
            sessions = len(self.client.keys("session:*"))
            blacklisted = len(self.client.keys("blacklist:*"))

            return {
                "status": "healthy",
                "hits": info.get("keyspace_hits", 0),
                "misses": info.get("keyspace_misses", 0),
                "sessions": sessions,
                "blacklisted_tokens": blacklisted,
                "memory_used": info.get("used_memory_human", "N/A")
            }
        except Exception as e:
            logger.error(f"Failed to get cache stats: {e}")
            return {"status": "error", "error": str(e)}

    def health_check(self) -> bool:
        """Check Redis health"""
        if not self.client:
            return False

        try:
            return self.client.ping()
        except Exception:
            return False


# Global cache instance
cache = Cache()
