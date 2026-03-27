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

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/send-otp")
async def send_otp(request: SendOTPRequest, db: AsyncSession = Depends(get_db)) -> dict:
    await auth_service.send_otp(db, request.phone)
    return {"success": True, "message": "OTP sent", "data": {}}

@router.post("/verify-otp", response_model=TokenResponse)
async def verify_otp(request: VerifyOTPRequest, db: AsyncSession = Depends(get_db)) -> dict:
    result = await auth_service.verify_otp_and_login(db, request.phone, request.otp)
    if result is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired OTP")
    return result

@router.post("/refresh")
async def refresh_token(request: RefreshRequest, db: AsyncSession = Depends(get_db)) -> dict:
    result = await auth_service.refresh_access_token(db, request.refresh_token)
    if result is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    return {"success": True, "data": result, "message": "Token refreshed"}

@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)) -> dict:
    return {
        "success": True,
        "data": {
            "id": str(current_user.id),
            "phone": current_user.phone,
            "role": current_user.role.value,
            "is_active": current_user.is_active,
        },
        "message": "User info",
    }
