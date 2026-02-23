from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Float
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base

class Plant(Base):
    __tablename__ = "plants"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String, index=True)
    species = Column(String, index=True)
    image_path = Column(String, nullable=True)
    current_location = Column(String, default="Indoor") # Indoor or Outdoor
    growth_stage = Column(Integer, default=0)
    x = Column(Float, default=0.0)
    y = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    owner = relationship("User", back_populates="plants")
    plant_state = relationship("PlantState", uselist=False, back_populates="plant", cascade="all, delete-orphan")
    disease_records = relationship("DiseaseRecord", back_populates="plant", cascade="all, delete-orphan")
    reminders = relationship("Reminder", back_populates="plant", cascade="all, delete-orphan")
    logs = relationship("PlantLog", back_populates="plant", cascade="all, delete-orphan")
