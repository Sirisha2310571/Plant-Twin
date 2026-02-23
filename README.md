# PlantTwin: Intelligent Plant Care Assistant 🌱📱

**PlantTwin** is a comprehensive, AI-powered Digital Twin application for indoor and outdoor plant care. It bridges the gap between physical plants and digital management by providing real-time identification, disease diagnosis, environmental monitoring, and personalized care schedules.

Built with a **Flutter** frontend and a **FastAPI** backend, PLantTwin leverages state-of-the-art **Deep Learning** models (ResNet/MobileNet) to help users keep their plants healthy and thriving.

---

## 🚀 Key Features

### 1. 🌿 AI-Powered Plant Identification
Instantly identify plants by simply taking a photo.
- **Technology**: Deep Convolutional Neural Networks (CNN).
- **Capabilities**: Recognizes **17 distinct plant species** primarily focused on popular indoor/household plants.
- **Output**: Provides common name, botanical name, and immediate access to care guides.

### 2. 🩺 Intelligent Disease Detection
Early diagnosis of plant health issues to prevent spread and damage.
- **Technology**: Specialized Image Classification models trained on plant pathology datasets.
- **Capabilities**: Detects **16 specific conditions**, including fungal infections (Rust, Anthracnose), bacterial issues, and pest damage (e.g., Mites), as well as confirming "Healthy" status.
- **Actionable Advice**: Returns diagnosis confidence and links to treatment recommendations.

### 3. 💧 Smart Care Reminders & Scheduling
Never forget to water or fertilize again.
- **Dynamic Scheduling**: specific schedules for Watering, Fertilizing, Pruning, and Repotting based on the specific plant species.
- **Push Notifications**: Timely alerts sent directly to the user's device.
- **Weather Adaptation**: (Planned) Adjusts watering needs based on local weather conditions.

### 4. 🌤️ Real-Time Weather Integration
Outdoor plant care optimized for your environment.
- Fetches real-time local weather data.
- Provides advice on whether to move plants indoors (e.g., during frost or heatwaves).

### 5. 📚 Comprehensive Plant Knowledge Base
- Detailed care profiles for supported plants.
- Information on:
    - **Sunlight**: Low, Medium, High light requirements.
    - **Watering**: Frequency and soil moisture needs.
    - **Temperature/Humidity**: Optimal growing conditions.
    - **Toxicity**: Pet safety warnings.

---

## 🛠️ Technical Architecture

The project is structured as a disjoint client-server application.

### 📱 Frontend (Mobile App)
- **Framework**: **Flutter** (Dart) - Cross-platform (iOS/Android).
- **State Management**: **Provider** / **BLoC** pattern for efficient data handling.
- **UI/UX**: Custom Material Design with **Google Fonts**, smooth animations, and responsive layout.
- **Key Libraries**:
    - `image_picker`: Camera/Gallery access.
    - `http`: REST API communication.
    - `shared_preferences`: Local data persistence.
    - `fl_chart`: Visualization of plant growth/health stats.
    - `intl`: Date/Time formatting for schedules.

### 🔙 Backend (API Server)
- **Framework**: **FastAPI** (Python 3.10+) - High-performance, async-ready web framework.
- **Database**: 
    - **SQLite** (Development) for lightweight, server-less data storage.
    - **PostgreSQL** (Production ready) supported via SQLAlchemy ORM.
- **ORM**: **SQLAlchemy** for database interactions.
- **Data Validation**: **Pydantic** models ensure type safety and request validation.
- **Task Scheduling**: **APScheduler** for managing background reminder tasks.
- **Authentication**: **OAuth2** with Password flow & **JWT** (JSON Web Tokens) for secure user sessions.

### 🧠 Machine Learning (The "Brain")
The core intelligence of GreenTwin is powered by PyTorch.

#### **Model Architecture**
We utilize **Transfer Learning** to leverage powerful pre-trained feature extractors:
- **Primary Architecture**: **ResNet18** (Residual Networks) or **MobileNetV2**.
    - *Why?* These models strike an excellent balance between accuracy and inference speed, making them ideal for near-real-time API responses.
    - **Pre-training**: Models were pre-trained on the **ImageNet** dataset to learn generic visual features (edges, textures, shapes).
- **Fine-Tuning**: The final classification layers (Fully Connected layers) were replaced and retrained specifically on our custom **Plant** and **Disease** datasets.

#### **1. Plant Identification Model (`universal_model-2.pth`)**
- **Classes**: 17
- **Input**: RGB Images, Resized to 224x224, Normalized.
- **Supported Plants**:
    - Aloe Vera, Anthurium, Begonia, Boston Fern, Calathea, Chinese Evergreen, Dumb Cane, Iron Cross Begonia, Monstera Deliciosa, Peace Lily, Pothos, Rattlesnake Plant, Rubber Plant, Schefflera, Snake Plant, Tradescantia, ZZ Plant.

#### **2. Disease Detection Model (`indoor_disease_model.pth`)**
- **Classes**: 16
- **supported Disease/Conditions**:
    - **Aloe**: Anthracnose, Leaf Spot, Rust, Sunburn, Healthy.
    - **Cactus**: Dactylopius, Healthy.
    - **Money Plant**: Bacterial Wilt, Manganese Toxicity, Healthy.
    - **Snake Plant**: Anthracnose, Leaf Withering, Healthy.
    - **Spider Plant**: Fungal Leaf Spot, Leaf Tip Necrosis, Healthy.

---

## 📂 Project Structure

```
Plant-Twin-main/
├── backend/                  # FastAPI Server
│   ├── app/
│   │   ├── ml_models/        # Raw model files (.pth)
│   │   ├── routers/          # API Endpoints (auth, plants, disease, etc.)
│   │   ├── services/         # Business Logic (ML inference, Scheduling)
│   │   └── main.py           # Application Entry Point
│   ├── requirements.md       # Python Dependencies
│   └── run_backend.sh        # Startup Script
├── plant_twin/               # Flutter Mobile App
│   ├── lib/
│   │   ├── models/           # Dart Data Models
│   │   ├── screens/          # UI Screens (Home, Camera, Profile)
│   │   ├── services/         # API Integration clients
│   │   └── main.dart         # App Entry Point
│   └── pubspec.yaml          # Dart Dependencies
└── README.md                 # Project Documentation
```

---

## 🚀 Getting Started

### Prerequisites
- **Python 3.10+** installed.
- **Flutter SDK** installed and configured.
- **Android Studio / VS Code** with Flutter extensions.

### 1. Backend Setup
Navigate to the `backend` directory and install dependencies.

```bash
cd backend
# Create a virtual environment (optional but recommended)
python -m venv venv
# Activate it:
# Windows: venv\Scripts\activate
# Mac/Linux: source venv/bin/activate

# Install dependencies
pip install -r requirements.md
```

Start the backend server:
```bash
# Using the helper script
./run_backend.sh

# OR manually with Uvicorn
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
The API will be available at `http://localhost:8000`.
API Docs (Swagger UI) are available at `http://localhost:8000/docs`.

### 2. Frontend Setup
Navigate to the `plant_twin` directory.

```bash
cd plant_twin

# Get Dart dependencies
flutter pub get

# Run the app (ensure an Emulator or Physical device is connected)
flutter run
```

---

## 🔗 API Documentation (Snapshot)

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| **POST** | `/auth/login` | Authenticate user & get JWT token |
| **POST** | `/auth/signup` | Register a new user account |
| **POST** | `/identify/` | Upload image to identify plant species |
| **POST** | `/disease/detect` | Upload image to detect plant diseases |
| **GET** | `/plants/` | Get list of user's saved plants |
| **POST** | `/plants/` | Add a new plant to user profile |
| **GET** | `/reminders/` | Get pending care tasks (water/fertilize) |

---

## 🤝 Contribution
Contributions are welcome! Please fork the repository and submit a Pull Request.

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
