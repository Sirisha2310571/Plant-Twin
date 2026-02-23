import torch
import torch.nn as nn
from torchvision import transforms, models
from PIL import Image
import json
import os
import io
from typing import Optional, Tuple, Dict, Any
from app.services.mapping import plant_mapping_service
from app.services.plant_data import plant_data_service

# Paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
MODEL_PATH = os.path.join(BASE_DIR, "models", "universal_model-2.pth")
CLASSES_PATH = os.path.join(BASE_DIR, "models", "classes-2.json")

class PlantIdentificationService:
    _instance = None
    _model = None
    _classes = []
    _device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(PlantIdentificationService, cls).__new__(cls)
            cls._instance._load_resources()
        return cls._instance

    def _load_resources(self):
        """Loads the PyTorch model and class labels."""
        # Load Classes
        if not os.path.exists(CLASSES_PATH):
            print(f"Error: Classes file not found at {CLASSES_PATH}")
            return
        
        try:
            with open(CLASSES_PATH, 'r') as f:
                self._classes = json.load(f)
            print(f"Loaded {len(self._classes)} classes.")
        except Exception as e:
            print(f"Error loading classes: {e}")
            with open("backend_debug_log.txt", "a") as f:
                f.write(f"Error loading classes: {e}\n")
            return

        # Load Model
        if not os.path.exists(MODEL_PATH):
            print(f"Error: Model file not found at {MODEL_PATH}")
            return

        try:
            # Recreate the model architecture
            # Assuming ResNet18 or similar based on common transfer learning practices
            # If the user's model is different, this might need adjustment.
            # Loading state_dict implies we need the same architecture.
            # Let's try loading it as a full model first (torch.load can save full model)
            # or try to infer architecture. 
            # Given "universal_model-2.pth", it might be a full model save.
            
            # 1. Try loading the file
            loaded_obj = torch.load(MODEL_PATH, map_location=self._device)

            # 2. Check if it's a full model or state dict
            if isinstance(loaded_obj, nn.Module):
                self._model = loaded_obj
            elif isinstance(loaded_obj, dict):
                # It's a state dict, trying MobileNetV2
                print("Loaded state dict, attempting to load into MobileNetV2...")
                try:
                    self._model = models.mobilenet_v2(weights=None)
                    self._model.classifier[1] = nn.Linear(1280, len(self._classes))
                    self._model.load_state_dict(loaded_obj)
                except Exception as e:
                    print(f"Failed to load as MobileNetV2: {e}")
                    # Try ResNet18
                    print("Attempting to load into ResNet18...")
                    self._model = models.resnet18(weights=None)
                    num_ftrs = self._model.fc.in_features
                    self._model.fc = nn.Linear(num_ftrs, len(self._classes))
                    self._model.load_state_dict(loaded_obj)
            else:
                print(f"Unknown model object type: {type(loaded_obj)}")
                return

            self._model.to(self._device)
            self._model.eval()
            print("Model loaded successfully.")
        except Exception as e:
            print(f"Error loading model: {e}")
            with open("backend_debug_log.txt", "a") as f:
                f.write(f"Error loading model: {e}\n")

    def _preprocess_image(self, image_bytes: bytes) -> torch.Tensor:
        """Preprocesses the image for the model."""
        transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ])
        
        image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
        return transform(image).unsqueeze(0).to(self._device)

    def identify_plant(self, image_bytes: bytes) -> Dict[str, Any]:
        """
        Identifies a plant from an image byte stream.
        Returns prediction details and mapped plant requirements.
        """
        if self._model is None or not self._classes:
            return {"error": "Model or classes not loaded properly."}

        try:
            input_tensor = self._preprocess_image(image_bytes)
            
            with torch.no_grad():
                outputs = self._model(input_tensor)
                probabilities = torch.nn.functional.softmax(outputs[0], dim=0)
                confidence, predicted_idx = torch.max(probabilities, 0)
            
            predicted_class = self._classes[predicted_idx.item()]
            confidence_score = confidence.item()
            
            # Resolve canonical name using Mapping Service
            canonical_name = plant_mapping_service.resolve_plant_name(predicted_class)
            
            # Fetch Requirements using Plant Data Service (if canonical name found)
            requirements = None
            if canonical_name:
                requirements = plant_data_service.get_plant_profile(canonical_name)
            
            return {
                "predicted_class": predicted_class,
                "confidence": confidence_score,
                "canonical_name": canonical_name,
                "requirements": requirements
            }

        except Exception as e:
            print(f"Error during identification: {e}")
            with open("backend_debug_log.txt", "a") as f:
                f.write(f"Error in identify_plant: {e}\n")
            return {"error": str(e)}

plant_identification_service = PlantIdentificationService()
