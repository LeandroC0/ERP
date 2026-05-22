from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database.connection import Base

class User(Base):
    __tablename__ = "users"

    id         = Column(Integer, primary_key=True, index=True)
    name       = Column(String(150), nullable=False)
    lastname   = Column(String(150), nullable=False)
    email      = Column(String(255), unique=True, nullable=False)
    password   = Column(String(255), nullable=False)
    phone      = Column(String(50), nullable=True)
    role_id    = Column(Integer, ForeignKey("role.id"), nullable=False)
    state_id   = Column(Integer, ForeignKey("state.id"), nullable=False)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    role  = relationship("Role")
    state = relationship("State")