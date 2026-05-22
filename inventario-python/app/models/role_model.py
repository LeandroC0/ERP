from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from app.database.connection import Base

class Role(Base):
    __tablename__ = "role"

    id          = Column(Integer, primary_key=True, index=True)
    name        = Column(String(100), nullable=False, unique=True)
    description = Column(String(255), nullable=True)
    state_id    = Column(Integer, ForeignKey("state.id"), nullable=False)

    state = relationship("State")