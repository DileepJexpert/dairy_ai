import re
from pydantic import BaseModel, field_validator, model_validator

class SendOTPRequest(BaseModel):
    phone: str

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        v = v.strip()
        if not re.match(r"^\d{10}$", v):
            raise ValueError("Phone must be exactly 10 digits")
        return v

class VerifyOTPRequest(BaseModel):
    phone: str
    otp: str

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        v = v.strip()
        if not re.match(r"^\d{10}$", v):
            raise ValueError("Phone must be exactly 10 digits")
        return v

    @field_validator("otp")
    @classmethod
    def validate_otp(cls, v: str) -> str:
        if not re.match(r"^\d{6}$", v):
            raise ValueError("OTP must be exactly 6 digits")
        return v


class PasswordAuthRequest(BaseModel):
    phone: str
    password: str
    username: str | None = None
    email: str | None = None
    display_name: str | None = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        v = v.strip()
        if not re.match(r"^\d{10}$", v):
            raise ValueError("Phone must be exactly 10 digits")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8 or len(v) > 72:
            raise ValueError("Password must be between 8 and 72 characters")
        if v == "Password@123":
            raise ValueError("Choose a password that is not a published demo password")
        return v

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str | None) -> str | None:
        if v is None or not v.strip():
            return None
        value = v.strip().lower()
        if not re.match(r"^[a-z0-9._]{3,30}$", value):
            raise ValueError("Username must be 3-30 letters, numbers, dots, or underscores")
        return value

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str | None) -> str | None:
        if v is None or not v.strip():
            return None
        value = v.strip().lower()
        if len(value) > 254 or not re.match(r"^[^\s@]+@[^\s@]+\.[^\s@]+$", value):
            raise ValueError("Enter a valid email address")
        return value

    @field_validator("display_name")
    @classmethod
    def validate_display_name(cls, v: str | None) -> str | None:
        if v is None or not v.strip():
            return None
        return v.strip()


class PasswordLoginRequest(BaseModel):
    identifier: str
    password: str

    @field_validator("identifier")
    @classmethod
    def validate_identifier(cls, v: str) -> str:
        value = v.strip().lower()
        if len(value) < 3 or len(value) > 254:
            raise ValueError("Enter your phone, username, or email")
        return value

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8 or len(v) > 72:
            raise ValueError("Password must be between 8 and 72 characters")
        return v


class ForgotPasswordRequest(BaseModel):
    identifier: str

    @field_validator("identifier")
    @classmethod
    def validate_identifier(cls, v: str) -> str:
        value = v.strip().lower()
        if len(value) < 3 or len(value) > 254:
            raise ValueError("Enter your phone, username, or email")
        return value


class ResetPasswordRequest(BaseModel):
    token: str = ""
    new_password: str

    @field_validator("token")
    @classmethod
    def validate_token(cls, v: str) -> str:
        if len(v.strip()) < 32:
            raise ValueError("Invalid reset token")
        return v.strip()

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: str) -> str:
        if len(v) < 8 or len(v) > 72:
            raise ValueError("Password must be between 8 and 72 characters")
        if v == "Password@123":
            raise ValueError("Choose a password that is not a published demo password")
        return v


class ProfileUpdateRequest(BaseModel):
    username: str | None = None
    email: str | None = None
    display_name: str | None = None

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str | None) -> str | None:
        if v is None:
            return None
        value = v.strip().lower()
        if not re.match(r"^[a-z0-9._]{3,30}$", value):
            raise ValueError("Username must be 3-30 letters, numbers, dots, or underscores")
        return value

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str | None) -> str | None:
        if v is None:
            return None
        value = v.strip().lower()
        if len(value) > 254 or not re.match(r"^[^\s@]+@[^\s@]+\.[^\s@]+$", value):
            raise ValueError("Enter a valid email address")
        return value

    @field_validator("display_name")
    @classmethod
    def validate_display_name(cls, v: str | None) -> str | None:
        if v is None:
            return None
        value = v.strip()
        if len(value) < 2 or len(value) > 120:
            raise ValueError("Display name must be 2-120 characters")
        return value

    @model_validator(mode="after")
    def not_empty(self):
        if self.username is None and self.email is None and self.display_name is None:
            raise ValueError("Provide at least one profile field")
        return self

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    role: str
    dashboard_url: str

class RefreshRequest(BaseModel):
    refresh_token: str

class UserResponse(BaseModel):
    id: str
    phone: str
    role: str
    is_active: bool

    model_config = {"from_attributes": True}
