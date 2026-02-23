import pandas as pd
import numpy as np
import os
from typing import Dict, List, Optional, Any

# Path to the CSV file
# Adjust path as needed based on where the app runs vs where the file is
CSV_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), "requirements_plant", "Indoor_Plant_Health_and_Growth_Factors.csv")

class PlantDataService:
    _instance = None
    _data: Optional[pd.DataFrame] = None
    _ideal_ranges: Dict[str, Dict[str, Any]] = {}

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(PlantDataService, cls).__new__(cls)
            cls._instance._load_data()
        return cls._instance

    def _load_data(self):
        """Loads the CSV data and computes statistics."""
        if not os.path.exists(CSV_PATH):
            print(f"Error: Dataset not found at {CSV_PATH}")
            return

        try:
            df = pd.read_csv(CSV_PATH)
            
            # Clean column names (strip whitespace)
            df.columns = df.columns.str.strip()
            
            self._data = df
            self._compute_ideal_ranges()
            print(f"Loaded plant data: {len(df)} records.")
        except Exception as e:
            print(f"Error loading plant data: {e}")

    def _compute_ideal_ranges(self):
        """
        Computes 'ideal' ranges for environmental factors based on high-health plants.
        Groups by Plant_ID vs Species. 
        Note: The CSV has 'Plant_ID' as the name column (e.g. 'Aloe vera').
        """
        if self._data is None:
            return

        # Filter for healthy plants (Health_Score >= 4)
        healthy_df = self._data[self._data['Health_Score'] >= 4]

        if healthy_df.empty:
            # Fallback to all data if no high health scores found (unlikely)
            healthy_df = self._data
        
        # Group by Plant_ID (which acts as Species Name in this dataset)
        grouped = healthy_df.groupby('Plant_ID')

        # Numerical columns to analyze
        numeric_cols = [
            'Room_Temperature_C', 
            'Humidity_%', 
            'Soil_Moisture_%', 
            'Watering_Frequency_days', 
            'Watering_Amount_ml',
            'Height_cm' # Useful for growth tracking context
        ]

        # Categorical/Mode columns
        categorical_cols = [
            'Sunlight_Exposure',
            'Soil_Type',
            'Fertilizer_Type'
        ]

        for plant_name, group in grouped:
            stats = {}
            
            # 1. Numerical Stats (10th-90th percentile to ignore outliers)
            for col in numeric_cols:
                if col in group.columns:
                    stats[col] = {
                        'min': float(group[col].min()),
                        'max': float(group[col].max()),
                        'mean': float(group[col].mean()),
                        'optimal_min': float(group[col].quantile(0.1)),
                        'optimal_max': float(group[col].quantile(0.9))
                    }
            
            # 2. Categorical Modes (Most common successful value)
            for col in categorical_cols:
                if col in group.columns and not group[col].empty:
                    stats[col] = group[col].mode()[0] if not group[col].mode().empty else "Unknown"
            
            self._ideal_ranges[plant_name] = stats

    def get_plant_names(self) -> List[str]:
        """Returns list of unique plant names in the dataset."""
        if self._data is None:
            return []
        return self._data['Plant_ID'].unique().tolist()

    def get_plant_profile(self, plant_name: str) -> Optional[Dict[str, Any]]:
        """Returns the ideal profile/stats for a given plant name."""
        return self._ideal_ranges.get(plant_name)

    def get_raw_data(self) -> Optional[pd.DataFrame]:
        return self._data

# Global instance
plant_data_service = PlantDataService()
