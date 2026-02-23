from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, Dict

from app import database
from app.models.user import User
from app.models.plant import Plant
from app.dependencies import get_current_user
from app.schemas.user_schema import UserOut

router = APIRouter(
    prefix="/users",
    tags=["Users"]
)

class LocationUpdate(BaseModel):
    latitude: float
    longitude: float

class GardenStats(BaseModel):
    total_plants: int
    flowering: int
    vegetables: int
    herbs: int
    streak_days: int # Mocked for now, or calculated from logs
    garden_status: str # Good/Average/Bad based on avg health

class UserProfile(UserOut):
    garden_stats: GardenStats

@router.get("/me", response_model=UserProfile)
def get_current_user_profile(
    db: Session = Depends(database.get_db),
    current_user: User = Depends(get_current_user)
):
    plants = db.query(Plant).filter(Plant.user_id == current_user.id).all()
    
    total = len(plants)
    flowering = 0
    vegetables = 0
    herbs = 0
    
    total_health = 0.0
    
    for plant in plants:
        # Simple categorization based on species name (mock logic)
        species_lower = plant.species.lower()
        if any(x in species_lower for x in ['rose', 'lily', 'flower', 'orchid', 'jasmine']):
            flowering += 1
        elif any(x in species_lower for x in ['tomato', 'pepper', 'spinach', 'carrot', 'potato']):
            vegetables += 1
        elif any(x in species_lower for x in ['basil', 'mint', 'thyme', 'oregano', 'tulsi']):
            herbs += 1
        else:
            # Default fallback for unclassified
            flowering += 1 

        if plant.plant_state:
            total_health += plant.plant_state.health_score
            
    avg_health = total_health / total if total > 0 else 100.0
    
    garden_status = "Good"
    if avg_health < 50:
        garden_status = "Needs Attention"
    elif avg_health < 80:
        garden_status = "Average"
        
    # --- Streak Calculation ---
    from app.models.plant_log import PlantLog
    from sqlalchemy import func
    from datetime import date, timedelta
    
    # 1. Fetch all distinct dates where this user had activity (logs)
    # Joining Plant to filter by user_id
    user_activity_dates = db.query(func.date(PlantLog.recorded_at)).join(Plant).filter(Plant.user_id == current_user.id).distinct().all()
    
    # Flat list of dates (sorted descending)
    dates = sorted([d[0] for d in user_activity_dates if d[0]], reverse=True)
    
    streak = 0
    if dates:
        today = date.today()
        # Check if streak is active (activity today or yesterday)
        if dates[0] == today:
             streak = 1
             check_date = today - timedelta(days=1)
        elif dates[0] == today - timedelta(days=1):
             streak = 1
             check_date = today - timedelta(days=2)
             # If most recent was yesterday, we start checking from day before yesterday, 
             # but we need to account that the *first* date in our list is yesterday.
             # Actually, simpler logic: Iterate and check continuity.
        else:
             streak = 0 # No activity recently
             
        if streak > 0:
            # We already counted the first valid day (today or yesterday)
            # Now check backwards
            
            # Re-eval simplistic loop
            streak = 0
            current_check = today
            
            # If no activity today, check if yesterday has activity to keep streak alive
            if dates[0] != current_check:
                if dates[0] == current_check - timedelta(days=1):
                    current_check = current_check - timedelta(days=1)
                else:
                    current_check = None # Streak broken/inactive
            
            if current_check:
                for d in dates:
                    if d == current_check:
                        streak += 1
                        current_check = current_check - timedelta(days=1)
                    else:
                        break # Gap found
    
    stats = GardenStats(
        total_plants=total,
        flowering=flowering,
        vegetables=vegetables,
        herbs=herbs,
        streak_days=streak,
        garden_status=garden_status
    )
    
    # Create response by copying user data and adding stats
    return UserProfile(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        garden_type=current_user.garden_type,
        city=current_user.city,
        garden_stats=stats
    )

@router.post("/location")
def update_location(
    loc_data: LocationUpdate, 
    db: Session = Depends(database.get_db), 
    current_user: User = Depends(get_current_user)
):
    try:
        current_user.latitude = loc_data.latitude
        current_user.longitude = loc_data.longitude
        db.commit()
        return {"message": "Location updated successfully"}
    except Exception as e:
        print(f"Error updating location: {e}")
        raise HTTPException(status_code=500, detail="Failed to update location")
class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    garden_type: Optional[str] = None
    city: Optional[str] = None

@router.put("/me", response_model=UserProfile)
def update_user_profile(
    user_update: UserUpdate,
    db: Session = Depends(database.get_db),
    current_user: User = Depends(get_current_user)
):
    if user_update.full_name is not None:
        current_user.full_name = user_update.full_name
    if user_update.garden_type is not None:
        current_user.garden_type = user_update.garden_type
    
    if hasattr(user_update, 'city') and user_update.city is not None:
        current_user.city = user_update.city
        from app.services.weather_service import weather_service
        coords = weather_service.get_coordinates_by_city(user_update.city)
        if coords:
            current_user.latitude = coords.get("latitude")
            current_user.longitude = coords.get("longitude")
    
    db.commit()
    db.refresh(current_user)
    
    # Re-fetch stats logic (reused from get_current_user_profile)
    # Ideally refactor this into a service, but for now duplicate for speed/safety
    plants = db.query(Plant).filter(Plant.user_id == current_user.id).all()
    total = len(plants)
    flowering = 0
    vegetables = 0
    herbs = 0
    total_health = 0.0
    
    for plant in plants:
        species_lower = plant.species.lower()
        if any(x in species_lower for x in ['rose', 'lily', 'flower', 'orchid', 'jasmine']):
            flowering += 1
        elif any(x in species_lower for x in ['tomato', 'pepper', 'spinach', 'carrot', 'potato']):
            vegetables += 1
        elif any(x in species_lower for x in ['basil', 'mint', 'thyme', 'oregano', 'tulsi']):
            herbs += 1
        else:
            flowering += 1 

        if plant.plant_state:
            total_health += plant.plant_state.health_score
            
    avg_health = total_health / total if total > 0 else 100.0
    
    garden_status = "Good"
    if avg_health < 50:
        garden_status = "Needs Attention"
    elif avg_health < 80:
        garden_status = "Average"

    # --- Streak Calculation (Duplicated for now) ---
    from app.models.plant_log import PlantLog
    from sqlalchemy import func
    from datetime import date, timedelta
    
    user_activity_dates = db.query(func.date(PlantLog.recorded_at)).join(Plant).filter(Plant.user_id == current_user.id).distinct().all()
    dates = sorted([d[0] for d in user_activity_dates if d[0]], reverse=True)
    
    streak = 0
    if dates:
        today = date.today()
        current_check = today
        
        if dates[0] != current_check:
            if dates[0] == current_check - timedelta(days=1):
                current_check = current_check - timedelta(days=1)
            else:
                current_check = None 
        
        if current_check:
            for d in dates:
                if d == current_check:
                    streak += 1
                    current_check = current_check - timedelta(days=1)
                else:
                    break
        
    stats = GardenStats(
        total_plants=total,
        flowering=flowering,
        vegetables=vegetables,
        herbs=herbs,
        streak_days=streak,
        garden_status=garden_status
    )
    
    return UserProfile(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        garden_type=current_user.garden_type,
        city=current_user.city,
        garden_stats=stats
    )
