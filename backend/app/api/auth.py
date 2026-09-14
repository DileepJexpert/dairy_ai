import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.config import get_settings
from app.schemas.auth import (
    SendOTPRequest, VerifyOTPRequest, TokenResponse,
    PasswordAuthRequest, PasswordLoginRequest, ForgotPasswordRequest,
    ResetPasswordRequest, ProfileUpdateRequest, RefreshRequest, UserResponse,
)
from app.services import auth_service, email_service

logger = logging.getLogger("dairy_ai.api.auth")

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register-password", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register_password(
    request: PasswordAuthRequest,
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await auth_service.register_with_password(
        db,
        request.phone,
        request.password,
        username=request.username,
        email=request.email,
        display_name=request.display_name,
    )
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account already exists for this phone, username, or email",
        )
    return result


@router.post("/login-password", response_model=TokenResponse)
async def login_password(
    request: PasswordLoginRequest,
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await auth_service.login_with_password(
        db, request.identifier, request.password
    )
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone, username, email, or password",
        )
    return result


@router.post("/forgot-password")
async def forgot_password(
    request: ForgotPasswordRequest,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Start recovery without revealing whether an identifier exists."""
    user, token = await auth_service.begin_password_reset(db, request.identifier)
    email_sent = False
    reset_url = None
    if user and token:
        settings = get_settings()
        reset_url = (
            f"{settings.STOREFRONT_BASE_URL.rstrip('/')}/#/reset-password?token={token}"
        )
        if user.email:
            try:
                email_sent = await email_service.send_password_reset_email(
                    user.email, reset_url
                )
            except Exception:
                logger.exception("Password reset email delivery failed")
    data = {}
    if get_settings().APP_ENV.lower() in {"development", "test"} and token:
        data = {
            "reset_token": token,
            "reset_url": reset_url,
            "email_sent": email_sent,
        }
    return {
        "success": True,
        "data": data,
        "message": (
            "If the account exists, password reset instructions are available."
        ),
    }


@router.post("/reset-password")
async def reset_password(
    request: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
) -> dict:
    if not await auth_service.reset_password(db, request.token, request.new_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Reset link is invalid or expired",
        )
    return {"success": True, "data": {}, "message": "Password updated"}

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
            "username": current_user.username,
            "email": current_user.email,
            "name": current_user.display_name,
            "role": current_user.role.value,
            "is_active": current_user.is_active,
            "dashboard_url": dashboard_url,
        },
        "message": "User info",
    }


@router.put("/me")
async def update_me(
    request: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    changes = request.model_dump(exclude_unset=True)
    if "username" in changes and changes["username"] is not None:
        changes["username"] = changes["username"].strip().lower()
    if "email" in changes and changes["email"] is not None:
        changes["email"] = changes["email"].strip().lower()
    if "display_name" in changes and changes["display_name"] is not None:
        changes["display_name"] = changes["display_name"].strip()
    identifiers = [
        value
        for key, value in changes.items()
        if key in {"username", "email"} and value
    ]
    if identifiers:
        duplicate = (
            await db.execute(
                select(User).where(
                    User.id != current_user.id,
                    or_(User.username.in_(identifiers), User.email.in_(identifiers)),
                )
            )
        ).scalars().first()
        if duplicate:
            raise HTTPException(409, "Username or email is already in use")
    for key, value in changes.items():
        setattr(current_user, key, value)
    await db.flush()
    return {
        "success": True,
        "data": {
            "id": str(current_user.id),
            "phone": current_user.phone,
            "username": current_user.username,
            "email": current_user.email,
            "name": current_user.display_name,
            "role": current_user.role.value,
            "is_active": current_user.is_active,
        },
        "message": "Profile updated",
    }
