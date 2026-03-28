import logging

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jwt.exceptions import PyJWTError as JWTError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User, UserRole
from app.services.auth_service import decode_token, get_user_by_id

logger = logging.getLogger("dairy_ai.dependencies")

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    token = credentials.credentials
    logger.debug("Authenticating user from Bearer token...")
    try:
        payload = decode_token(token)
        logger.debug(f"Token decoded successfully: user_id={payload.get('sub')}, role={payload.get('role')}")
    except JWTError as e:
        logger.warning(f"JWT decode failed: {e}")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    if payload.get("type") != "access":
        logger.warning(f"Invalid token type: {payload.get('type')} (expected 'access')")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token type")

    user_id = payload.get("sub")
    if user_id is None:
        logger.warning("Token has no 'sub' claim")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    user = await get_user_by_id(db, user_id)
    if user is None or not user.is_active:
        logger.warning(f"User not found or inactive: user_id={user_id}")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or inactive")

    logger.info(f"Authenticated user: id={user.id}, phone={user.phone}, role={user.role.value}")
    return user

def require_role(*roles: UserRole):
    role_names = [r.value for r in roles]
    logger.debug(f"Creating role checker for roles: {role_names}")
    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in roles:
            logger.warning(f"Access denied: user {current_user.id} has role '{current_user.role.value}', required: {role_names}")
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions")
        logger.debug(f"Role check passed: user {current_user.id} has role '{current_user.role.value}'")
        return current_user
    return role_checker
