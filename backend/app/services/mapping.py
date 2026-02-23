import json
import os
import difflib
from typing import Optional, Dict

# Path to the JSON mapping file
MAPPING_FILE_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), "requirements_plant", "mapping.json")

class PlantMappingService:
    _instance = None
    _mapping: Dict[str, str] = {}
    
    # Map AI classes to frontend assets folder names
    _folder_mapping = {
        "Aloe Vera": "aloe_vera",
        "Anthurium (Anthurium andraeanum)": "anthurium",
        "Begonia (Begonia spp.)": "begonia",
        "Boston Fern (Nephrolepis exaltata)": "boston_fern",
        "Calathea": "calathea",
        "Chinese evergreen (Aglaonema)": "chinese",
        "Dumb Cane (Dieffenbachia spp.)": "dumb_cane",
        "Iron Cross begonia (Begonia masoniana)": "iron_cross_begonia",
        "Monstera Deliciosa (Monstera deliciosa)": "monstera",
        "Peace lily": "peace_lily",
        "Pothos (Ivy arum)": "pothos",
        "Rattlesnake Plant (Calathea lancifolia)": "rattlesnake_plant",
        "Rubber Plant (Ficus elastica)": "rubber",
        "Schefflera": "schefflera",
        "Snake plant (Sanseviera)": "snake_plant",
        "Tradescantia": "tradescantia",
        "ZZ Plant (Zamioculcas zamiifolia)": "zz_plant"
    }
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(PlantMappingService, cls).__new__(cls)
            cls._instance._load_mapping()
        return cls._instance

    def _load_mapping(self):
        """Loads the manual mapping JSON."""
        if not os.path.exists(MAPPING_FILE_PATH):
            print(f"Warning: Mapping file not found at {MAPPING_FILE_PATH}")
            return
        
        try:
            with open(MAPPING_FILE_PATH, 'r') as f:
                self._mapping = json.load(f)
            
            # Normalize keys for easier lookup (lowercase, stripped)
            self._normalized_mapping = {k.lower().strip(): v for k, v in self._mapping.items()}
            print(f"Loaded {len(self._mapping)} plant mappings.")
        except Exception as e:
            print(f"Error loading plant mapping: {e}")
            self._normalized_mapping = {}

    def resolve_plant_name(self, input_name: str) -> Optional[str]:
        """
        Resolves a user input string to a canonical Plant_ID found in the dataset.
        1. Exact match (case-insensitive) in mapping.
        2. Fuzzy match in mapping keys.
        3. Fuzzy match against known dataset Plant_IDs (from PlantDataService).
        """
        if not input_name:
            return None
        
        normalized_input = input_name.lower().strip()

        # 1. Check manual mapping (O(1))
        if normalized_input in self._normalized_mapping:
            return self._normalized_mapping[normalized_input]

        # 2. Fuzzy match against mapping keys
        # Get closest match if similarity is high enough
        mapping_keys = list(self._normalized_mapping.keys())
        matches = difflib.get_close_matches(normalized_input, mapping_keys, n=1, cutoff=0.6)
        
        if matches:
            best_match_key = matches[0]
            print(f"Fuzzy matched '{input_name}' to mapping key '{best_match_key}' -> {self._normalized_mapping[best_match_key]}")
            return self._normalized_mapping[best_match_key]

        # 3. Fuzzy match against canonical names (Simulating "Search")
        # Creating instance here to avoid circular import at top level if possible, 
        # or better: inject dependency. For simplicity in this script:
        from app.services.plant_data import PlantDataService
        pds = PlantDataService()
        known_plants = pds.get_plant_names()
        
        # Normalize known plants for matching
        known_plants_lower = {p.lower(): p for p in known_plants}
        
        # Check exact match against canonical
        if normalized_input in known_plants_lower:
            return known_plants_lower[normalized_input]
            
        # Check fuzzy match against canonical
        matches_canonical = difflib.get_close_matches(normalized_input, list(known_plants_lower.keys()), n=1, cutoff=0.6)
        if matches_canonical:
            best_canonical_key = matches_canonical[0]
            canonical_name = known_plants_lower[best_canonical_key]
            print(f"Fuzzy matched '{input_name}' to canonical '{canonical_name}'")
            return canonical_name

        return None

    def resolve_folder_name(self, class_name: str) -> str:
        """Resolves an AI class name to a frontend asset folder name."""
        return self._folder_mapping.get(class_name, "monstera") # Default to monstera if unknown

plant_mapping_service = PlantMappingService()
