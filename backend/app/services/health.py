from typing import Dict, List, Optional, Any
from app.services.plant_data import plant_data_service

class HealthAssessmentService:
    def assess_health(self, plant_name: str, conditions: Dict[str, float]) -> Dict[str, Any]:
        """
        Assesses plant health based on current environmental conditions vs ideal ranges.
        
        Args:
            plant_name: Canonical plant name (Plant_ID).
            conditions: Dictionary of environmental factors (e.g., {'temperature': 22.0, 'humidity': 50}).
        
        Returns:
            Dictionary with health_score, risk_level, warnings, and recommendations.
        """
        
        profile = plant_data_service.get_plant_profile(plant_name)
        
        if not profile:
            return {
                "error": f"Plant profile not found for '{plant_name}'",
                "health_score": None
            }

        warnings = []
        recommendations = []
        deviations = 0

        # Mapping conditions to internal keys
        # Caller might provide 'temperature', but internal is 'Room_Temperature_C'
        key_map = {
            'temperature': 'Room_Temperature_C',
            'humidity': 'Humidity_%',
            'soil_moisture': 'Soil_Moisture_%',
            'watering_frequency': 'Watering_Frequency_days',
            'watering_amount': 'Watering_Amount_ml'
        }

        # Check each condition
        for input_key, value in conditions.items():
            internal_key = key_map.get(input_key, input_key) # Use direct key if no mapping
            
            if internal_key in profile:
                stats = profile[internal_key]
                min_val = stats.get('min')
                max_val = stats.get('max')
                optimal_min = stats.get('optimal_min', min_val) 
                optimal_max = stats.get('optimal_max', max_val)

                # Simple range check
                if value < optimal_min:
                    deviations += 1
                    # Slightly more readable warnings
                    feature = input_key.replace('_', ' ').capitalize()
                    warnings.append(f"{feature} is too low ({value}). Ideal is {optimal_min:.1f}-{optimal_max:.1f}.")
                    recommendations.append(f"Increase {feature}.")
                elif value > optimal_max:
                    deviations += 1
                    feature = input_key.replace('_', ' ').capitalize()
                    warnings.append(f"{feature} is too high ({value}). Ideal is {optimal_min:.1f}-{optimal_max:.1f}.")
                    recommendations.append(f"Decrease {feature}.")

        # Compute Health Score (Simple Heuristic for now)
        # Assuming scale of 1-5 where 5 is best
        # Lose 1 point per deviation
        initial_score = 5
        health_score = max(1, initial_score - deviations)

        # Risk Level
        risk_level = "Good"
        if health_score == 4:
            risk_level = "Fair"
        elif health_score == 3:
            risk_level = "Warning"
        elif health_score < 3:
            risk_level = "Critical"

        return {
            "plant_name": plant_name,
            "health_score": health_score,
            "risk_level": risk_level,
            "warnings": warnings,
            "recommendations": recommendations,
            "ideal_ranges": profile # Returning context is helpful
        }

health_assessment_service = HealthAssessmentService()
