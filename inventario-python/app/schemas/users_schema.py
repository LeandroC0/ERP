from pydantic import BaseModel, EmailStr
from datetime import datetime

class UserCreate(BaseModel):
    name: str
    lastname: str
    email: EmailStr
    password: str
    phone: str | None = None
    role_id: int
    state_id: int

class UserResponse(BaseModel):
    id: int
    name: str
    lastname: str
    email: EmailStr
    phone: str | None
    role_id: int
    state_id: int
    created_at: datetime

    class Config:
        from_attributes = True