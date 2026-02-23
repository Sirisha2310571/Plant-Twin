from typing import Dict, Any, Optional
from app.models.plant import Plant
from app.services.plant_data import plant_data_service

class MoistureEstimatorService:
    @staticmethod
    def calculate_moisture(plant: Plant, weather_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Calculates estimated soil moisture and temperature based on weather data.
        
        Logic:
        1. Base dryness_ratio is calculated from days since last watered vs ideal frequency.
        2. Weather factor adjusts dryness:
           - Temp > 30°C: +20%
           - Temp 25-30°C: +10%
           - Humidity > 70%: -15%
           - Humidity < 40%: +10%
        3. moisture_score = 100 - (adjusted_dryness * 100)
        """
        temp = weather_data.get("temperature", 25.0)
        humidity = weather_data.get("humidity", 50.0)
        
        # 1. Get Plant Profile
        from app.services.mapping import plant_mapping_service
        canonical_name = plant_mapping_service.resolve_plant_name(plant.species)
        if not canonical_name:
            canonical_name = plant_mapping_service.resolve_plant_name(plant.name)
            
        profile = plant_data_service.get_plant_profile(canonical_name)
        ideal_water_freq = 7.0
        if profile:
            w_stats = profile.get('Watering_Frequency_days')
            if w_stats:
                ideal_water_freq = w_stats.get('mean', 7.0)
        
        # 2. Base Dryness Ratio
        from datetime import datetime
        last_watered = plant.plant_state.last_watered if plant.plant_state else plant.created_at
        if not last_watered:
            last_watered = plant.created_at
            
        days_since_water = (datetime.utcnow() - last_watered).total_seconds() / (24 * 3600)
        dryness_ratio = days_since_water / ideal_water_freq
        
        # 3. Weather Adjustment
        weather_factor = 1.0
        if temp > 30:
            weather_factor += 0.2
        elif 25 <= temp <= 30:
            weather_factor += 0.1
            
        if humidity > 70:
            weather_factor -= 0.15
        elif humidity < 40:
            weather_factor += 0.1
            
        adjusted_dryness = dryness_ratio * weather_factor
        
        # 4. Moisture Score
        moisture_score = max(0, min(100, 100 - (adjusted_dryness * 100)))
        
        # 5. Interpretation
        if moisture_score >= 70:
            level = "Moist"
            interpretation = "Soil likely moist"
        elif moisture_score >= 40:
            level = "Medium"
            interpretation = "Moderately moist"
        else:
            level = "Dry"
            interpretation = "Likely dry"
            
        # 6. Soil Temp
        soil_temp = temp - 2.0 # Simple approximation
        
        # 7. Recommendation
        recommendation = "No watering needed"
        if moisture_score < 40:
            recommendation = "Water now"
        elif moisture_score < 60:
            recommendation = "Check again in 2 days"
            
        # Sunlight Placement Check
        sun_advice = ""
        if profile:
            light_needs = profile.get('Sunlight_Exposure', '').lower()
            if 'full sun' in light_needs or 'bright' in light_needs:
                if 20 <= temp <= 30:
                    sun_advice = " Keep the plant outdoor for sunlight today."
        
        return {
            "moisture_score": round(moisture_score, 1),
            "moisture_level": level,
            "interpretation": interpretation,
            "soil_temperature": round(soil_temp, 1),
            "recommendation": recommendation + sun_advice
        }

moisture_estimator = MoistureEstimatorService()
