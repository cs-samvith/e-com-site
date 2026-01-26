"""
E-Commerce Metrics Instrumentation for User Service
Tracks user-related business metrics and technical metrics for Prometheus
"""

from prometheus_client import Counter, Histogram, Gauge, generate_latest
from functools import wraps
import time

# =============================================================================
# Business Metrics - User Service
# =============================================================================

# User Registrations
user_registrations_total = Counter(
    'user_registrations_total',
    'Total number of user registrations',
    ['source']  # web, mobile, api
)

# User Login Attempts
user_login_attempts_total = Counter(
    'user_login_attempts_total',
    'Total number of login attempts',
    ['status', 'method']  # status: success/failed, method: email/social
)

# Active Sessions
user_active_sessions = Gauge(
    'user_active_sessions',
    'Number of active user sessions'
)

# Session Creation
user_sessions_created_total = Counter(
    'user_sessions_created_total',
    'Total number of sessions created'
)

# Password Reset
user_password_reset_requests_total = Counter(
    'user_password_reset_requests_total',
    'Total number of password reset requests',
    ['status']  # initiated, completed, failed
)

# Profile Updates
user_profile_updates_total = Counter(
    'user_profile_updates_total',
    'Total number of profile updates',
    ['field']  # email, name, address, preferences
)

# Email Verifications
user_email_verifications_total = Counter(
    'user_email_verifications_total',
    'Total number of email verifications',
    ['status']  # sent, verified, failed
)

# Account Actions
user_account_actions_total = Counter(
    'user_account_actions_total',
    'Total number of account actions',
    ['action']  # deactivate, reactivate, delete
)

# =============================================================================
# Technical Metrics - HTTP
# =============================================================================

http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint'],
    buckets=[0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0]
)

# =============================================================================
# Authentication Metrics
# =============================================================================

# JWT Token Operations
jwt_tokens_issued_total = Counter(
    'jwt_tokens_issued_total',
    'Total number of JWT tokens issued',
    ['token_type']  # access, refresh
)

jwt_tokens_validated_total = Counter(
    'jwt_tokens_validated_total',
    'Total number of JWT token validations',
    ['status']  # valid, expired, invalid
)

jwt_tokens_revoked_total = Counter(
    'jwt_tokens_revoked_total',
    'Total number of JWT tokens revoked',
    ['reason']  # logout, security, expired
)

# Authentication Duration
auth_operation_duration_seconds = Histogram(
    'auth_operation_duration_seconds',
    'Authentication operation duration in seconds',
    ['operation'],
    buckets=[0.01, 0.05, 0.1, 0.5, 1.0]
)

# =============================================================================
# Database Metrics
# =============================================================================

database_query_duration_seconds = Histogram(
    'database_query_duration_seconds',
    'Database query duration in seconds',
    ['operation', 'table'],
    buckets=[0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0]
)

database_connections_active = Gauge(
    'database_connections_active',
    'Number of active database connections'
)

database_connections_idle = Gauge(
    'database_connections_idle',
    'Number of idle database connections'
)

# =============================================================================
# Cache Metrics
# =============================================================================

redis_cache_hits_total = Counter(
    'redis_cache_hits_total',
    'Total number of cache hits',
    ['cache_key_type']
)

redis_cache_misses_total = Counter(
    'redis_cache_misses_total',
    'Total number of cache misses',
    ['cache_key_type']
)

redis_operations_total = Counter(
    'redis_operations_total',
    'Total Redis operations',
    ['operation']
)

# =============================================================================
# Security Metrics
# =============================================================================

# Failed Login Attempts (Security)
failed_login_attempts_by_ip = Counter(
    'failed_login_attempts_by_ip',
    'Failed login attempts grouped by IP',
    ['ip_address']
)

# Suspicious Activities
suspicious_activities_total = Counter(
    'suspicious_activities_total',
    'Total number of suspicious activities detected',
    ['activity_type']  # brute_force, unusual_location, rapid_requests
)

# Rate Limiting
rate_limit_exceeded_total = Counter(
    'rate_limit_exceeded_total',
    'Total number of rate limit violations',
    ['endpoint', 'user_id']
)

# =============================================================================
# Decorator Functions
# =============================================================================


def track_endpoint_metrics(endpoint_name):
    """Decorator to track HTTP endpoint metrics"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            start_time = time.time()
            status_code = 200

            try:
                response = await func(*args, **kwargs)
                if hasattr(response, 'status_code'):
                    status_code = response.status_code
                return response
            except Exception as e:
                status_code = 500
                raise
            finally:
                duration = time.time() - start_time

                http_requests_total.labels(
                    method='POST',  # or extract from request
                    endpoint=endpoint_name,
                    status=status_code
                ).inc()

                http_request_duration_seconds.labels(
                    method='POST',
                    endpoint=endpoint_name
                ).observe(duration)

        return wrapper
    return decorator


def track_auth_operation(operation):
    """Decorator to track authentication operations"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            start_time = time.time()

            try:
                result = await func(*args, **kwargs)
                return result
            finally:
                duration = time.time() - start_time
                auth_operation_duration_seconds.labels(
                    operation=operation
                ).observe(duration)

        return wrapper
    return decorator


# =============================================================================
# Helper Functions
# =============================================================================

def track_user_registration(source: str = 'web'):
    """Track a new user registration"""
    user_registrations_total.labels(source=source).inc()


def track_login_attempt(success: bool, method: str = 'email'):
    """Track a login attempt"""
    status = 'success' if success else 'failed'
    user_login_attempts_total.labels(
        status=status,
        method=method
    ).inc()


def track_failed_login_by_ip(ip_address: str):
    """Track failed login attempt by IP for security monitoring"""
    failed_login_attempts_by_ip.labels(ip_address=ip_address).inc()


def track_session_creation():
    """Track a new session creation"""
    user_sessions_created_total.inc()


def update_active_sessions(count: int):
    """Update the count of active sessions"""
    user_active_sessions.set(count)


def track_password_reset(status: str):
    """Track password reset requests"""
    user_password_reset_requests_total.labels(status=status).inc()


def track_profile_update(field: str):
    """Track profile field updates"""
    user_profile_updates_total.labels(field=field).inc()


def track_email_verification(status: str):
    """Track email verification events"""
    user_email_verifications_total.labels(status=status).inc()


def track_account_action(action: str):
    """Track account-level actions"""
    user_account_actions_total.labels(action=action).inc()


def track_jwt_issued(token_type: str = 'access'):
    """Track JWT token issuance"""
    jwt_tokens_issued_total.labels(token_type=token_type).inc()


def track_jwt_validated(status: str):
    """Track JWT token validation"""
    jwt_tokens_validated_total.labels(status=status).inc()


def track_jwt_revoked(reason: str):
    """Track JWT token revocation"""
    jwt_tokens_revoked_total.labels(reason=reason).inc()


def track_suspicious_activity(activity_type: str):
    """Track suspicious activities for security"""
    suspicious_activities_total.labels(
        activity_type=activity_type
    ).inc()


def track_rate_limit_exceeded(endpoint: str, user_id: str = 'anonymous'):
    """Track rate limit violations"""
    rate_limit_exceeded_total.labels(
        endpoint=endpoint,
        user_id=user_id
    ).inc()


# =============================================================================
# Metrics Endpoint
# =============================================================================

def get_metrics():
    """Return Prometheus metrics in text format"""
    return generate_latest()
