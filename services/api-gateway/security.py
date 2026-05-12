import os
import logging
from fastapi import HTTPException, Request
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

logger = logging.getLogger(__name__)

IAP_AUDIENCE = os.getenv("IAP_AUDIENCE", "")


async def verify_iap_jwt(request: Request) -> dict:
    """
    Validates the IAP JWT passed in the X-Goog-IAP-JWT-Assertion header.
    Raises HTTP 401 if the token is missing or invalid.
    """
    if not IAP_AUDIENCE:
        logger.warning("IAP_AUDIENCE not set — skipping JWT validation")
        return {}

    token = request.headers.get("X-Goog-IAP-JWT-Assertion")
    if not token:
        raise HTTPException(
            status_code=401,
            detail="Missing IAP assertion header"
        )

    try:
        claims = id_token.verify_token(
            token,
            google_requests.Request(),
            audience=IAP_AUDIENCE,
            certs_url="https://www.gstatic.com/iap/verify/public_key"
        )
        logger.info("IAP JWT verified for user: %s", claims.get("email"))
        return claims

    except Exception as exc:
        logger.error("IAP JWT verification failed: %s", exc)
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired IAP token"
        )
