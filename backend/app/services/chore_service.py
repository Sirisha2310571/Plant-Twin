from datetime import datetime, timedelta
from typing import List, Dict, Any
from app.models.plant import Plant
from app.models.plant_state import PlantState
from app.services.plant_data import plant_data_service

class ChoreService:
    @staticmethod
    def generate_chores(plant: Plant, current_temp: float = 25.0, precip_prob: float = 0.0) -> List[Dict[str, Any]]:
        """
        Generates a list of chores for a specific plant based on its state and environment.
        """
        chores = []
        
        # 1. Resolve Plant Profile
        # We need to know what kind of plant it is to know its needs
        # Resolve species name using the mapping service (or just use stored species if clean)
        from app.services.mapping import plant_mapping_service
        canonical_name = plant_mapping_service.resolve_plant_name(plant.species)
        if not canonical_name:
            canonical_name = plant_mapping_service.resolve_plant_name(plant.name)
            
        profile = plant_data_service.get_plant_profile(canonical_name)
        
        # Defaults if profile missing
        ideal_water_freq = 7 # days
        min_temp = 10.0
        max_temp = 32.0
        
        if profile:
            # parsing "7 days" or similar if string, but our CSV loader tries to make it float/int
            # The CSV loader implementation set numeric stats.
            # Let's assume 'Watering_Frequency_days' is in 'mean' or 'optimal_min'
            # Check structure of stats in plant_data.py
            w_stats = profile.get('Watering_Frequency_days')
            if w_stats:
                ideal_water_freq = w_stats.get('mean', 7)
                
            t_stats = profile.get('Room_Temperature_C')
            if t_stats:
                min_temp = t_stats.get('optimal_min', 10.0)
                max_temp = t_stats.get('optimal_max', 35.0)

        # 2. Watering Chore
        # Logic: If (Now - LastWatered) >= Frequency, add task.
        last_watered = plant.plant_state.last_watered if plant.plant_state else plant.created_at
        if not last_watered:
             last_watered = plant.created_at
             
        days_since_water = (datetime.utcnow() - last_watered).days
        
        # Dynamic Adjustment: If it's hot, water sooner? (Future refinement)
        
        if days_since_water >= ideal_water_freq:
            # Check for rain if outdoor?
            if plant.current_location == "Outdoor" and precip_prob > 50:
                 # It's raining, no need to water!
                 pass 
            else:
                due_date = last_watered + timedelta(days=ideal_water_freq)
                overdue_days = days_since_water - ideal_water_freq
                
                status = "Due Today"
                priority = "Normal"
                if overdue_days > 0:
                    status = f"Overdue by {int(overdue_days)} days"
                    priority = "High"
                
                chores.append({
                    "id": "water",
                    "plant_id": plant.id,
                    "plant_name": plant.name,
                    "title": "Water Plant",
                    "description": f"Your {plant.name} needs water every {int(ideal_water_freq)} days.",
                    "status": status,
                    "priority": priority,
                    "icon": "water_drop"
                })

        # 3. Location / Temperature Chore
        # "Outdoor" check
        if plant.current_location == "Outdoor":
            if current_temp < min_temp:
                 chores.append({
                    "id": "move_in_cold",
                    "plant_id": plant.id,
                    "plant_name": plant.name,
                    "title": "Move Indoors",
                    "description": f"It's too cold ({current_temp}°C) for {plant.name}. Minimum tolerance is {min_temp}°C.",
                    "status": "Critical",
                    "priority": "Urgent",
                    "icon": "home"
                })
            elif current_temp > max_temp:
                 chores.append({
                    "id": "check_heat",
                    "plant_id": plant.id,
                    "plant_name": plant.name,
                    "title": "Check Heat Stress",
                    "description": f"Temperature ({current_temp}°C) exceeds ideal max ({max_temp}°C). Ensure shade or move indoors.",
                    "status": "Warning",
                    "priority": "High",
                    "icon": "thermostat"
                })
                
        # 4. Moisture Estimation (NEW)
        from app.services.moisture_estimator import moisture_estimator
        weather_data = {"temperature": current_temp, "humidity": 50.0} # Humidity could be fetched too
        
        # Try to get humidity if we have coords and weather service
        try:
            from app.services.weather_service import weather_service
            # This is a bit complex as we don't have user here, but we can pass coords or fetch if needed
            # For now, current_temp is passed in.
            pass
        except:
            pass
            
        estimation = moisture_estimator.calculate_moisture(plant, weather_data)
        
        chores.append({
            "id": "moisture_probe",
            "plant_id": plant.id,
            "plant_name": plant.name,
            "title": "Moisture & Environment",
            "description": f"Moisture: {estimation['moisture_score']}% ({estimation['moisture_level']}). {estimation['recommendation']}",
            "status": "Info",
            "priority": "Normal",
            "icon": "opacity",
            "metadata": estimation
        })

        return chores

chore_service = ChoreService()
