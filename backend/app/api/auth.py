import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.auth import (
    SendOTPRequest, VerifyOTPRequest, TokenResponse,
    RefreshRequest, UserResponse,
)
from app.services import auth_service

logger = logging.getLogger("dairy_ai.api.auth")

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/send-otp")
async def send_otp(request: SendOTPRequest, db: AsyncSession = Depends(get_db)) -> dict:
    logger.info(f"POST /auth/send-otp called | phone=****{request.phone[-4:]}")
    logger.debug(f"Calling auth_service.send_otp for phone=****{request.phone[-4:]}")
    try:
        await auth_service.send_otp(db, request.phone)
        logger.info(f"OTP sent successfully to phone=****{request.phone[-4:]}")
        return {"success": True, "message": "OTP sent", "data": {}}
    except Exception as e:
        logger.error(f"Failed to send OTP to phone=****{request.phone[-4:]}: {e}")
        raise

@router.post("/verify-otp", response_model=TokenResponse)
async def verify_otp(request: VerifyOTPRequest, db: AsyncSession = Depends(get_db)) -> dict:
    logger.info(f"POST /auth/verify-otp called | phone=****{request.phone[-4:]}")
    logger.debug(f"Calling auth_service.verify_otp_and_login for phone=****{request.phone[-4:]}")
    try:
        result = await auth_service.verify_otp_and_login(db, request.phone, request.otp)
        if result is None:
            logger.warning(f"Invalid or expired OTP for phone=****{request.phone[-4:]}")
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired OTP")
        logger.info(f"OTP verified successfully for phone=****{request.phone[-4:]} | user logged in")
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to verify OTP for phone=****{request.phone[-4:]}: {e}")
        raise

@router.post("/refresh")
async def refresh_token(request: RefreshRequest, db: AsyncSession = Depends(get_db)) -> dict:
    logger.info("POST /auth/refresh called")
    logger.debug("Calling auth_service.refresh_access_token")
    try:
        result = await auth_service.refresh_access_token(db, request.refresh_token)
        if result is None:
            logger.warning("Token refresh failed — invalid refresh token provided")
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
        logger.info("Access token refreshed successfully")
        return {"success": True, "data": result, "message": "Token refreshed"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to refresh token: {e}")
        raise

@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)) -> dict:
    logger.info(f"GET /auth/me called | user_id={current_user.id} | role={current_user.role.value}")
    logger.debug(f"Returning user info for user_id={current_user.id}")

    from app.models.user import UserRole
    role_dashboard_map = {
        UserRole.farmer: "/api/v1/farmers/me/dashboard",
        UserRole.vet: "/api/v1/vets/me/dashboard",
        UserRole.vendor: "/api/v1/vendor/dashboard",
        UserRole.cooperative: "/api/v1/cooperative/dashboard",
        UserRole.admin: "/api/v1/admin/dashboard",
        UserRole.super_admin: "/api/v1/super-admin/dashboard",
    }
    dashboard_url = role_dashboard_map.get(current_user.role, "/api/v1/farmers/me/dashboard")
    logger.debug(f"Dashboard URL for user | role={current_user.role.value} | dashboard_url={dashboard_url}")

    return {
        "success": True,
        "data": {
            "id": str(current_user.id),
            "phone": current_user.phone,
            "role": current_user.role.value,
            "is_active": current_user.is_active,
            "dashboard_url": dashboard_url,
        },
        "message": "User info",
    }
