from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
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
    created_at = Column(DateTime, default=datetime.utcnow)
    
    owner = relationship("User", back_populates="plants")
    plant_state = relationship("PlantState", uselist=False, back_populates="plant", cascade="all, delete-orphan")
    disease_records = relationship("DiseaseRecord", back_populates="plant", cascade="all, delete-orphan")
    reminders = relationship("Reminder", back_populates="plant", cascade="all, delete-orphan")
    logs = relationship("PlantLog", back_populates="plant", cascade="all, delete-orphan")
