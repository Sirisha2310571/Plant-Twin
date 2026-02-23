from fastapi import APIRouter, File, UploadFile, HTTPException
from typing import Dict, Any
from app.services.plant_identification import plant_identification_service

router = APIRouter(
    prefix="/identification",
    tags=["identification"],
    responses={404: {"description": "Not found"}},
)

@router.post("/identify")
async def identify_plant(file: UploadFile = File(...)) -> Dict[str, Any]:
    """
    Identifies a plant from an uploaded image.
    Returns the predicted class, confidence, canonical name, and care requirements.
    """
    if not file:
        raise HTTPException(status_code=400, detail="No file uploaded")
    
    # Read the file content
    contents = await file.read()
    
    # Perform identification
    result = plant_identification_service.identify_plant(contents)
    
    if "error" in result:
        raise HTTPException(status_code=500, detail=result["error"])
        
    return result
