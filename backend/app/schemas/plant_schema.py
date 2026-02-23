from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from .plant_state_schema import PlantStateOut

class PlantBase(BaseModel):
    name: str
    species: str
    growth_stage: Optional[int] = 0
    x: Optional[float] = 0.0
    y: Optional[float] = 0.0

class PlantCreate(PlantBase):
    pass

from .plant_log_schema import PlantLogOut
from .disease_record_schema import DiseaseRecordOut

class PlantOut(PlantBase):
    id: int
    user_id: int
    image_path: Optional[str] = None
    created_at: datetime
    plant_state: Optional[PlantStateOut] = None
    logs: List[PlantLogOut] = []
    disease_records: List[DiseaseRecordOut] = []
    
    class Config:
        from_attributes = True
