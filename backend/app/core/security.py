from fastapi import Header, HTTPException, status

from app.core.config import settings

async def verify_api_key(x_api_key: str = Header(default=None)) -> None:

    if not settings.API_KEY_ENABLED:
        return
    if x_api_key is None or x_api_key != settings.API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing X-API-Key header.",
        )