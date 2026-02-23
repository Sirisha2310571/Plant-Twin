from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session, joinedload
from typing import List
import shutil
import os
import uuid

from app import database
from app.models.plant import Plant
from app.models.plant_state import PlantState
from app.models.disease_record import DiseaseRecord
from app.models.user import User
from app.schemas.plant_schema import PlantCreate, PlantOut
from app.dependencies import get_current_user
from app.ml.inference import inference_service

router = APIRouter(
    prefix="/plants",
    tags=["Plants"]
)

@router.get("/", response_model=List[PlantOut])
def get_plants(db: Session = Depends(database.get_db), current_user: User = Depends(get_current_user)):
    return db.query(Plant).filter(Plant.user_id == current_user.id).all()

@router.post("/", response_model=PlantOut)
async def create_plant(
    name: str = Form(...),
    species: str = Form(None),
    growth_stage: int = Form(0),
    x: float = Form(0.0),
    y: float = Form(0.0),
    file: UploadFile = File(...),
    db: Session = Depends(database.get_db),
    current_user: User = Depends(get_current_user)
):
    # 1. Read Image Content
    file_bytes = await file.read()
    
    # 2. Identify Plant (Fallback if species not provided)
    if not species or species == "unknown":
        from app.services.plant_identification import plant_identification_service
        from app.services.mapping import plant_mapping_service
        
        identification_result = plant_identification_service.identify_plant(file_bytes)
        
        if "error" in identification_result:
            raise HTTPException(status_code=500, detail=identification_result["error"])
            
        predicted_class = identification_result.get("predicted_class", "Monstera Deliciosa (Monstera deliciosa)")
        confidence = identification_result.get("confidence", 0.0)
        
        # Map class to folder name for frontend assets
        species = plant_mapping_service.resolve_folder_name(predicted_class)
        print(f"DEBUG: AI Identified {predicted_class} -> Mapping to folder: {species}")
    else:
        confidence = 1.0 # Manually selected
        
    print(f"DEBUG: Using Species: {species}")

    # 3. Save Image
    UPLOAD_DIR = "uploads"
    if not os.path.exists(UPLOAD_DIR):
        os.makedirs(UPLOAD_DIR)
    
    file_extension = file.filename.split(".")[-1]
    filename = f"{uuid.uuid4()}.{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, filename)
    
    with open(file_path, "wb") as buffer:
        buffer.write(file_bytes)
        
    # 4. Calculate Initial Health (Default to 100 for new plants)
    # We removed the "Disease Detection" logic because the model predicts species, not diseases.
    initial_health = 100.0
    initial_risk = 0.0
    
    # 5. Create Plant
    new_plant = Plant(
        name=name,
        species=species, 
        user_id=current_user.id,
        image_path=f"uploads/{filename}",
        growth_stage=growth_stage,
        x=x,
        y=y
    )
    db.add(new_plant)
    db.commit()
    db.refresh(new_plant)
    
    # 6. Create Twin State
    new_state = PlantState(
        plant_id=new_plant.id,
        health_score=initial_health,
        disease_risk_index=initial_risk
    )
    db.add(new_state)
    
    # 7. Create Initial Log/Record (Optional, identifying record)
    new_record = DiseaseRecord(
        plant_id=new_plant.id,
        predicted_class=species, # Log the species
        confidence=confidence,
        image_path=f"uploads/{filename}"
    )
    db.add(new_record)
    
    db.commit()
    db.refresh(new_plant)
    
    return new_plant

from app.models.plant_log import PlantLog
from app.schemas.plant_log_schema import PlantLogCreate, PlantLogOut

@router.get("/{plant_id}", response_model=PlantOut)
def get_plant(plant_id: int, db: Session = Depends(database.get_db), current_user: User = Depends(get_current_user)):
    # Eager load plant_state, logs, and disease_records
    plant = db.query(Plant).options(
        joinedload(Plant.plant_state), 
        joinedload(Plant.logs),
        joinedload(Plant.disease_records)
    ).filter(Plant.id == plant_id, Plant.user_id == current_user.id).first()
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
    return plant

@router.post("/{plant_id}/log", response_model=PlantLogOut)
async def log_growth(
    plant_id: int, 
    height: float = Form(...),
    file: UploadFile = File(None), # Optional image
    db: Session = Depends(database.get_db), 
    current_user: User = Depends(get_current_user)
):
    plant = db.query(Plant).options(joinedload(Plant.plant_state)).filter(Plant.id == plant_id, Plant.user_id == current_user.id).first()
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
    
    current_health = plant.plant_state.health_score if plant.plant_state else 100.0
    
    image_path = None
    if file:
        UPLOAD_DIR = "uploads"
        if not os.path.exists(UPLOAD_DIR):
            os.makedirs(UPLOAD_DIR)
        
        file_extension = file.filename.split(".")[-1]
        filename = f"log_{uuid.uuid4()}.{file_extension}"
        file_path = os.path.join(UPLOAD_DIR, filename)
        
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        image_path = f"uploads/{filename}"

    new_log = PlantLog(
        plant_id=plant_id,
        height=height,
        health_score=current_health,
        image_path=image_path
    )
    db.add(new_log)
    db.commit()
    db.refresh(new_log)
    return new_log

@router.delete("/{plant_id}")
def delete_plant(plant_id: int, db: Session = Depends(database.get_db), current_user: User = Depends(get_current_user)):
    plant = db.query(Plant).filter(Plant.id == plant_id, Plant.user_id == current_user.id).first()
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
    
    # Manual logs cascade if needed, but we set cascade in model.
    # We rely on SQLAlchemy cascades for clean cleanup now
    db.delete(plant)
        
    db.commit()
    return {"message": "Plant deleted successfully"}

@router.post("/{plant_id}/water")
def water_plant(plant_id: int, db: Session = Depends(database.get_db), current_user: User = Depends(get_current_user)):
    from app.services.twin_engine import TwinEngine
    
    plant = db.query(Plant).options(joinedload(Plant.plant_state)).filter(Plant.id == plant_id, Plant.user_id == current_user.id).first()
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
        
    if plant.plant_state:
        current_stress = plant.plant_state.water_stress
        message = "Plant watered."
        
        # Smart Logic: Check for Overwatering via Twin Engine
        # Fetch weather context (Mocked for now)
        from app.services.weather_service import WeatherService
        precip_prob = 0.0 # WeatherService.get_precip() - To be implemented
        
        if not TwinEngine.should_water(plant.plant_state, precip_prob):
             # Auto-Pilot Interception (Not used in direct button click usually, but good for background tasks)
             # For direct user action, we proceed but might warn.
             pass

        if plant.plant_state.water_stress < 0.2: # Less than 20% stress
            # Overwatering Analysis
            # Don't just deduct -2. Calculate impact.
            # Increase Water Stres (Root Rot risk) instead of decreasing it!
            plant.plant_state.water_stress = min(1.0, plant.plant_state.water_stress + 0.3) 
            plant.plant_state.health_score = TwinEngine.calculate_health_score(plant.plant_state)
            
            message = "Careful! Soil is wet. Overwatering risks root rot."
        else:
            # Proper Watering
            # Simulate Recovery Logic (Lag)
            plant.plant_state = TwinEngine.simulate_recovery(plant.plant_state, water_added=True)
            # Recalculate based on new stress
            plant.plant_state.health_score = TwinEngine.calculate_health_score(plant.plant_state)
            
            # Dynamic Feedback
            gain = plant.plant_state.health_score - 0 # rough delta check needed? 
            message = "Plant watered. Absorption in progress..."

        db.add(plant.plant_state)
        db.commit()
        db.refresh(plant.plant_state)
        
        try:
            # Fetch last known height (or default 0)
            from app.models.plant_log import PlantLog
            last_log = db.query(PlantLog).filter(PlantLog.plant_id == plant_id).order_by(PlantLog.recorded_at.desc()).first()
            current_height = last_log.height if last_log else 0.0

            watering_log = PlantLog(
                plant_id=plant_id,
                height=current_height, # Maintain height
                health_score=plant.plant_state.health_score,
                image_path=None # No image for watering action
            )
            db.add(watering_log)
            
            # Update last_watered timestamp
            from datetime import datetime
            plant.plant_state.last_watered = datetime.utcnow()
            db.add(plant.plant_state)
            
            db.commit()
        except Exception as e:
            print(f"Error logging watering event: {e}")

        
    return {"message": message, "new_health": plant.plant_state.health_score}

from pydantic import BaseModel

class EnvironmentUpdate(BaseModel):
    temperature: float

@router.post("/{plant_id}/environment")
def update_environment(
    plant_id: int, 
    env_data: EnvironmentUpdate, 
    db: Session = Depends(database.get_db), 
    current_user: User = Depends(get_current_user)
):
    from app.services.twin_engine import TwinEngine
    
    plant = db.query(Plant).options(joinedload(Plant.plant_state)).filter(Plant.id == plant_id, Plant.user_id == current_user.id).first()
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
        
    if plant.plant_state:
        plant.plant_state = TwinEngine.update_from_environment(plant.plant_state, env_data.temperature)
        db.add(plant.plant_state)
        db.commit()
        db.refresh(plant.plant_state)
        
    return {
        "message": "Environment updated", 
        "health_score": plant.plant_state.health_score,
        "heat_stress": plant.plant_state.heat_stress
    }
@router.post("/{plant_id}/stage")
def update_stage(
    plant_id: int, 
    stage: str = Form(...), 
    db: Session = Depends(database.get_db), 
    current_user: User = Depends(get_current_user)
):
    plant = db.query(Plant).options(joinedload(Plant.plant_state)).filter(Plant.id == plant_id, Plant.user_id == current_user.id).first()
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
        
    if plant.plant_state:
        plant.plant_state.growth_stage = stage
        
        # Sync with garden growth_stage (int)
        stages = ["Seedling", "Vegetative", "Flowering", "Fruiting", "HarvestReady"]
        if stage in stages:
            plant.growth_stage = stages.index(stage)
            
        db.add(plant.plant_state)
        db.add(plant)
        db.commit()
        db.refresh(plant.plant_state)
        db.refresh(plant)
        
    return {"message": "Growth stage updated", "new_stage": plant.plant_state.growth_stage, "garden_stage": plant.growth_stage}
@router.post("/identify")
def identify_plant(name: str = Form(...)):
    """
    Identifies a plant from a manual name input using fuzzy matching against the dataset.
    """
    from app.services.mapping import plant_mapping_service
    from app.services.plant_data import plant_data_service
    
    canonical_name = plant_mapping_service.resolve_plant_name(name)
    
    if not canonical_name:
         raise HTTPException(status_code=404, detail=f"Plant '{name}' not found in database.")
         
    profile = plant_data_service.get_plant_profile(canonical_name)
    
    return {
        "input_name": name,
        "canonical_name": canonical_name,
        "profile": profile
    }

@router.get("/{plant_id}/profile")
def get_plant_profile_endpoint(plant_id: int, db: Session = Depends(database.get_db), current_user: User = Depends(get_current_user)):
    """
    Returns the ideal care profile for a user's specific plant based on its species.
    """
    plant = db.query(Plant).filter(Plant.id == plant_id, Plant.user_id == current_user.id).first()
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
        
    # We assume 'species' column holds the canonical name or close to it
    # We might need to resolve it again just in case the stored species name isn't perfect
    from app.services.mapping import plant_mapping_service
    from app.services.plant_data import plant_data_service
    
    canonical_name = plant_mapping_service.resolve_plant_name(plant.species)
    if not canonical_name:
        # Fallback to name?
        canonical_name = plant_mapping_service.resolve_plant_name(plant.name)
        
    if not canonical_name:
         return {"message": "Profile not available for this species", "species": plant.species}
         
    profile = plant_data_service.get_plant_profile(canonical_name)
    return {"plant_id": plant.id, "species": canonical_name, "profile": profile}

from pydantic import BaseModel

class HealthCheckInput(BaseModel):
    temperature: float
    humidity: float
    soil_moisture: float
    watering_frequency: float

@router.post("/{plant_id}/health/assess")
def assess_plant_health(
    plant_id: int, 
    conditions: HealthCheckInput,
    db: Session = Depends(database.get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Assess plant health based on current environmental conditions.
    """
    plant = db.query(Plant).filter(Plant.id == plant_id, Plant.user_id == current_user.id).first()
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
    
    from app.services.mapping import plant_mapping_service
    from app.services.health import health_assessment_service
    
    # Resolve species to canonical name
    canonical_name = plant_mapping_service.resolve_plant_name(plant.species)
    if not canonical_name:
         # Try name
         canonical_name = plant_mapping_service.resolve_plant_name(plant.name)
         
    if not canonical_name:
        raise HTTPException(status_code=400, detail=f"Could not resolve species '{plant.species}' to a known plant profile.")
    
    # Run assessment
    assessment = health_assessment_service.assess_health(
        canonical_name, 
        conditions.model_dump()
    )
    
    return assessment

@router.get("/{plant_id}/chores")
def get_plant_chores(
    plant_id: int,
    db: Session = Depends(database.get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get dynamic chores for a plant based on its state and environment.
    """
    plant = db.query(Plant).options(joinedload(Plant.plant_state)).filter(Plant.id == plant_id, Plant.user_id == current_user.id).first()
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")

    # Mock environment data for now (or fetch from weather service)
    current_temp = 24.0 
    precip_prob = 10.0
    
    from app.services.chore_service import chore_service
    chores = chore_service.generate_chores(plant, current_temp, precip_prob)
    
    return chores

class LocationUpdate(BaseModel):
    location: str # "Indoor" or "Outdoor"

@router.put("/{plant_id}/location")
def update_plant_location(
    plant_id: int,
    loc_data: LocationUpdate,
    db: Session = Depends(database.get_db),
    current_user: User = Depends(get_current_user)
):
    plant = db.query(Plant).filter(Plant.id == plant_id, Plant.user_id == current_user.id).first()
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
        
    plant.current_location = loc_data.location
    db.commit()
    
    return {"message": "Location updated", "new_location": plant.current_location}

@router.post("/{plant_id}/check-health")
async def check_plant_health(
    plant_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(database.get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Analyzes an uploaded image to detect plant diseases.
    """
    plant = db.query(Plant).filter(Plant.id == plant_id, Plant.user_id == current_user.id).first()
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")

    # 1. Read Image
    file_bytes = await file.read()
    
    # 2. Detect Disease
    from app.services.disease_detection import disease_detection_service
    result = disease_detection_service.detect_disease(file_bytes)
    
    if "error" in result:
        raise HTTPException(status_code=500, detail=result["error"])
        
    return result

@router.get("/chores/all")
def get_all_chores(
    db: Session = Depends(database.get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get dynamic chores for ALL plants owned by the user.
    """
    plants = db.query(Plant).options(joinedload(Plant.plant_state)).filter(Plant.user_id == current_user.id).all()
    
    all_chores = []
    # Mock environment data for now
    current_temp = 24.0 
    precip_prob = 10.0
    
    from app.services.chore_service import chore_service
    
    for plant in plants:
        plant_chores = chore_service.generate_chores(plant, current_temp, precip_prob)
        all_chores.extend(plant_chores)
        
    # Sort by priority: Urgent > High > Normal
    priority_map = {"Urgent": 0, "High": 1, "Normal": 2}
    all_chores.sort(key=lambda x: priority_map.get(x.get("priority", "Normal"), 3))
    
    return all_chores

