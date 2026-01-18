from app.queue import queue_publisher
from app.cache import cache
from app.auth import auth_handler
from app.models import (
    User, UserCreate, UserUpdate, UserLogin, UserPasswordUpdate,
    Token, Session, UserEvent, HealthResponse
)
from app.config import settings
from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.responses import Response
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import List, Optional
from uuid import UUID
import logging
from datetime import datetime, timedelta
from prometheus_client import Counter, Histogram, generate_latest
import secrets

# Configure logging FIRST
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Import app modules

# Determine which database to use
if settings.MOCK_MODE:
    logger.info("MOCK_MODE=True: Using mock in-memory database")
    from app.mock_database import MockDatabase
    db = MockDatabase()
    USE_REAL_DB = False
elif settings.DB_HOST in ['postgres-service']:
    logger.info(f"DB_HOST={settings.DB_HOST}: Using mock in-memory database")
    from app.mock_database import MockDatabase
    db = MockDatabase()
    USE_REAL_DB = False
else:
    try:
        logger.info(
            f"Attempting to connect to PostgreSQL at {settings.DB_HOST}:{settings.DB_PORT}")
        from app.database import db
        if db.health_check():
            logger.info("✓ Connected to PostgreSQL - using real database")
            USE_REAL_DB = True
        else:
            logger.warning(
                "PostgreSQL health check failed - using mock database")
            from app.mock_database import MockDatabase
            db = MockDatabase()
            USE_REAL_DB = False
    except Exception as e:
        logger.warning(
            f"Failed to initialize PostgreSQL: {e}. Using mock database.")
        from app.mock_database import MockDatabase
        db = MockDatabase()
        USE_REAL_DB = False


# Prometheus metrics
REQUEST_COUNT = Counter(
    'user_service_requests_total',
    'Total requests',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'user_service_request_duration_seconds',
    'Request latency',
    ['method', 'endpoint']
)

# Create FastAPI app
app = FastAPI(
    title="User Service",
    description="Microservice for user authentication and management",
    version="1.0.0"
)

# Security scheme for Swagger UI
security = HTTPBearer()


# Dependency: Get current user from token (for Swagger)
async def get_current_user_swagger(credentials: HTTPAuthorizationCredentials = Depends(security)) -> User:
    """Get current authenticated user from JWT token (Swagger compatible)"""
    token = credentials.credentials

    # Check if token is blacklisted
    if cache.is_token_blacklisted(token):
        logger.warning("Token is blacklisted")
        raise HTTPException(status_code=401, detail="Token has been revoked")

    # Decode token
    token_data = auth_handler.decode_token(token)
    if not token_data:
        logger.warning("Invalid or expired token")
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    # Get user from database
    user = db.get_user_by_id(token_data.user_id)
    if not user:
        logger.warning(f"User not found for token: {token_data.user_id}")
        raise HTTPException(status_code=401, detail="User not found")

    logger.info(f"User authenticated: {user.email}")
    return user


# Dependency: Get current user from token (for direct API calls)
async def get_current_user(authorization: Optional[str] = Header(None)) -> User:
    """Get current authenticated user from JWT token"""
    if not authorization:
        logger.warning("No authorization header provided")
        raise HTTPException(status_code=401, detail="Not authenticated")

    # Extract token from "Bearer <token>"
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        logger.warning(
            f"Invalid authorization header format: {authorization[:50]}")
        raise HTTPException(
            status_code=401, detail="Invalid authentication header")

    token = parts[1]

    # Check if token is blacklisted
    if cache.is_token_blacklisted(token):
        logger.warning("Token is blacklisted")
        raise HTTPException(status_code=401, detail="Token has been revoked")

    # Decode token
    token_data = auth_handler.decode_token(token)
    if not token_data:
        logger.warning("Invalid or expired token")
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    # Get user from database
    user = db.get_user_by_id(token_data.user_id)
    if not user:
        logger.warning(f"User not found for token: {token_data.user_id}")
        raise HTTPException(status_code=401, detail="User not found")

    logger.info(f"User authenticated: {user.email}")
    return user


@app.on_event("startup")
async def startup_event():
    """Initialize service on startup"""
    logger.info(f"Starting {settings.SERVICE_NAME}...")

    # Initialize database
    try:
        db.init_db()
        logger.info("Database initialized")
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")

    # Connect to RabbitMQ
    try:
        queue_publisher.connect()
        logger.info("RabbitMQ connected")
    except Exception as e:
        logger.error(f"Failed to connect to RabbitMQ: {e}")

    logger.info(
        f"{settings.SERVICE_NAME} started successfully on port {settings.SERVICE_PORT}")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down...")
    queue_publisher.close()


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": settings.SERVICE_NAME,
        "status": "running",
        "version": "1.0.0",
        "endpoints": {
            "health": "/healthz",
            "ready": "/ready",
            "metrics": "/metrics",
            "register": "/api/users/register",
            "login": "/api/users/login",
            "profile": "/api/users/profile",
            "docs": "/docs"
        }
    }


@app.get("/healthz", response_model=HealthResponse)
async def health_check():
    """Liveness probe - is the service alive?"""
    return HealthResponse(
        status="healthy",
        service=settings.SERVICE_NAME
    )


@app.get("/ready", response_model=HealthResponse)
async def readiness_check():
    """Readiness probe - is the service ready to accept traffic?"""
    dependencies = {
        "database": db.health_check(),
        "cache": cache.health_check(),
        "queue": queue_publisher.health_check()
    }

    is_ready = dependencies["database"]

    return HealthResponse(
        status="ready" if is_ready else "not_ready",
        service=settings.SERVICE_NAME,
        dependencies=dependencies
    )


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(), media_type="text/plain")


@app.post("/api/users/register", response_model=User, status_code=201)
async def register_user(user_create: UserCreate):
    """Register a new user"""
    try:
        with REQUEST_LATENCY.labels(method="POST", endpoint="/api/users/register").time():
            # Create user
            new_user = db.create_user(user_create)

            # Publish user.created event
            event = UserEvent(
                event="user.created",
                data={
                    "user_id": str(new_user.id),
                    "email": new_user.email,
                    "first_name": new_user.first_name,
                    "last_name": new_user.last_name
                }
            )
            queue_publisher.publish_event(event)

        REQUEST_COUNT.labels(
            method="POST", endpoint="/api/users/register", status="201").inc()
        logger.info(f"User registered: {new_user.email}")
        return new_user

    except ValueError as e:
        REQUEST_COUNT.labels(
            method="POST", endpoint="/api/users/register", status="409").inc()
        raise HTTPException(status_code=409, detail=str(e))
    except Exception as e:
        REQUEST_COUNT.labels(
            method="POST", endpoint="/api/users/register", status="500").inc()
        logger.error(f"Error registering user: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.post("/api/users/login", response_model=Token)
async def login(user_login: UserLogin):
    """User login - authenticate and return JWT token"""
    try:
        with REQUEST_LATENCY.labels(method="POST", endpoint="/api/users/login").time():
            # Authenticate user
            user = db.authenticate_user(user_login.email, user_login.password)

            if not user:
                REQUEST_COUNT.labels(
                    method="POST", endpoint="/api/users/login", status="401").inc()
                raise HTTPException(
                    status_code=401, detail="Invalid email or password")

            # Create JWT token
            token = auth_handler.create_access_token(user.id, user.email)

            # Create session
            session_id = secrets.token_urlsafe(32)
            session = Session(
                session_id=session_id,
                user_id=user.id,
                email=user.email,
                created_at=datetime.utcnow(),
                expires_at=datetime.utcnow() + timedelta(seconds=settings.SESSION_TTL)
            )
            cache.store_session(session)

            # Publish user.login event
            event = UserEvent(
                event="user.login",
                data={
                    "user_id": str(user.id),
                    "email": user.email,
                    "timestamp": datetime.utcnow().isoformat()
                }
            )
            queue_publisher.publish_event(event)

        REQUEST_COUNT.labels(
            method="POST", endpoint="/api/users/login", status="200").inc()
        logger.info(f"User logged in: {user.email}")
        return token

    except HTTPException:
        raise
    except Exception as e:
        REQUEST_COUNT.labels(
            method="POST", endpoint="/api/users/login", status="500").inc()
        logger.error(f"Error during login: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.post("/api/users/logout", status_code=204)
async def logout(current_user: User = Depends(get_current_user), authorization: str = Header(None)):
    """User logout - invalidate token"""
    try:
        # Extract token
        token = authorization.split()[1]

        # Blacklist token
        cache.blacklist_token(token, settings.JWT_EXPIRATION_MINUTES * 60)

        # Publish user.logout event
        event = UserEvent(
            event="user.logout",
            data={
                "user_id": str(current_user.id),
                "email": current_user.email,
                "timestamp": datetime.utcnow().isoformat()
            }
        )
        queue_publisher.publish_event(event)

        logger.info(f"User logged out: {current_user.email}")
        return Response(status_code=204)

    except Exception as e:
        logger.error(f"Error during logout: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.get("/api/users/profile", response_model=User)
async def get_profile(current_user: User = Depends(get_current_user_swagger)):
    """Get current user profile"""
    return current_user


@app.put("/api/users/profile", response_model=User)
async def update_profile(
    user_update: UserUpdate,
    current_user: User = Depends(get_current_user_swagger)
):
    """Update current user profile"""
    try:
        updated_user = db.update_user(current_user.id, user_update)

        if not updated_user:
            raise HTTPException(status_code=404, detail="User not found")

        logger.info(f"User profile updated: {current_user.email}")
        return updated_user

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating profile: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.put("/api/users/password")
async def change_password(
    password_update: UserPasswordUpdate,
    current_user: User = Depends(get_current_user_swagger)
):
    """Change user password"""
    try:
        # Verify old password
        user_in_db = db.get_user_by_email(current_user.email)
        if not user_in_db:
            raise HTTPException(status_code=404, detail="User not found")

        if not auth_handler.verify_password(password_update.old_password, user_in_db.password_hash):
            raise HTTPException(status_code=400, detail="Invalid old password")

        # Update password
        success = db.update_password(
            current_user.id, password_update.new_password)

        if not success:
            raise HTTPException(
                status_code=500, detail="Failed to update password")

        logger.info(f"Password changed for user: {current_user.email}")
        return {"message": "Password updated successfully"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error changing password: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.get("/api/users", response_model=List[User])
async def get_users(
    limit: int = 100,
    offset: int = 0,
    current_user: User = Depends(get_current_user_swagger)
):
    """Get all users (admin endpoint - simplified, no real auth check)"""
    try:
        users = db.get_users(limit=limit, offset=offset)
        return users
    except Exception as e:
        logger.error(f"Error getting users: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.get("/api/users/{user_id}", response_model=User)
async def get_user(
    user_id: UUID,
    current_user: User = Depends(get_current_user_swagger)
):
    """Get user by ID"""
    try:
        user = db.get_user_by_id(user_id)

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        return user
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting user: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.get("/debug/cache-stats")
async def get_cache_stats():
    """Get cache statistics (for debugging)"""
    return cache.get_cache_stats()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=settings.SERVICE_PORT,
        reload=False,
        log_level="info"
    )
