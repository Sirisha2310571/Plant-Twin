import torch
import torch.nn as nn
from torchvision import transforms, models
from PIL import Image
import json
import os
import io
from typing import Dict, Any

# Paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
MODEL_PATH = os.path.join(BASE_DIR, "models", "indoor_disease_model.pth")
CLASSES_PATH = os.path.join(BASE_DIR, "models", "disease_classes.json")

class DiseaseDetectionService:
    _instance = None
    _model = None
    _classes = []
    _device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(DiseaseDetectionService, cls).__new__(cls)
            cls._instance._load_resources()
        return cls._instance

    def _load_resources(self):
        """Loads the Disease Detection Model and Classes."""
        # Load Classes
        if not os.path.exists(CLASSES_PATH):
            print(f"Error: Disease classes file not found at {CLASSES_PATH}")
            return
        
        try:
            with open(CLASSES_PATH, 'r') as f:
                self._classes = json.load(f)
            print(f"Loaded {len(self._classes)} disease classes.")
        except Exception as e:
            print(f"Error loading disease classes: {e}")
            return

        # Load Model
        if not os.path.exists(MODEL_PATH):
            print(f"Error: Disease model file not found at {MODEL_PATH}")
            return

        try:
            # Attempt to load model
            # Assuming ResNet18 based on file size/standard practice, or infer from saved object
            loaded_obj = torch.load(MODEL_PATH, map_location=self._device)

            if isinstance(loaded_obj, nn.Module):
                self._model = loaded_obj
            elif isinstance(loaded_obj, dict):
                # State dict
                # Try common architectures
                try:
                    # Try ResNet18 first as it's common for this task size
                    self._model = models.resnet18(weights=None)
                    num_ftrs = self._model.fc.in_features
                    self._model.fc = nn.Linear(num_ftrs, len(self._classes))
                    self._model.load_state_dict(loaded_obj)
                except Exception as e:
                    print(f"Failed ResNet18 load: {e}")
                    # Try MobileNetV2
                    try: 
                        self._model = models.mobilenet_v2(weights=None)
                        self._model.classifier[1] = nn.Linear(1280, len(self._classes))
                        self._model.load_state_dict(loaded_obj)
                    except Exception as e2:
                        print(f"Failed MobileNetV2 load: {e2}")
                        return
            
            if self._model:
                self._model.to(self._device)
                self._model.eval()
                print("Disease Detection Model loaded successfully.")
                
        except Exception as e:
            print(f"Error loading disease model: {e}")

    def _preprocess_image(self, image_bytes: bytes) -> torch.Tensor:
        """Preprocesses the image for the model (224x224, Normalized)."""
        transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ])
        
        image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
        return transform(image).unsqueeze(0).to(self._device)

    def detect_disease(self, image_bytes: bytes) -> Dict[str, Any]:
        """
        Analyzes an image for plant diseases.
        """
        if self._model is None or not self._classes:
            return {"error": "Disease model not loaded."}

        try:
            input_tensor = self._preprocess_image(image_bytes)
            
            with torch.no_grad():
                outputs = self._model(input_tensor)
                probabilities = torch.nn.functional.softmax(outputs[0], dim=0)
                confidence, predicted_idx = torch.max(probabilities, 0)
            
            predicted_class = self._classes[predicted_idx.item()]
            confidence_score = confidence.item()
            
            return {
                "diagnosis": predicted_class,
                "confidence": confidence_score,
                "is_healthy": "healthy" in predicted_class.lower()
            }

        except Exception as e:
            print(f"Error during disease detection: {e}")
            return {"error": str(e)}

disease_detection_service = DiseaseDetectionService()
