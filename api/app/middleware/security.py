"""Security middleware: headers, request size limits, and request ID tracking."""

import uuid
import logging
import time

from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

logger = logging.getLogger(__name__)

# 11 MB max body (matches nginx client_max_body_size)
MAX_BODY_SIZE = 11 * 1024 * 1024


class SecurityMiddleware(BaseHTTPMiddleware):
    """Adds security headers, request IDs, and body size enforcement."""

    async def dispatch(self, request: Request, call_next) -> Response:
        # Generate request ID for tracing
        request_id = str(uuid.uuid4())[:8]
        request.state.request_id = request_id

        # Enforce request body size limit
        if request.headers.get("content-length"):
            content_length = int(request.headers["content-length"])
            if content_length > MAX_BODY_SIZE:
                raise HTTPException(
                    status_code=413,
                    detail=f"Request body too large ({content_length} bytes). Max: {MAX_BODY_SIZE}.",
                )

        # Time the request
        start = time.time()
        response = await call_next(request)
        elapsed_ms = int((time.time() - start) * 1000)

        # Log request (structured format)
        logger.info(
            f"[{request_id}] {request.method} {request.url.path} "
            f"→ {response.status_code} ({elapsed_ms}ms)"
        )

        # Security headers
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["X-Request-ID"] = request_id

        # HSTS only in production
        if not request.url.hostname or request.url.hostname != "localhost":
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains"
            )

        return response
