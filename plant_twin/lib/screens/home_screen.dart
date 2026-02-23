import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/garden_plant.dart';
import '../widgets/plant_widget.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<GardenPlant> _gardenPlants = [];
  late AnimationController _backgroundController;
  late Animation<double> _skyAnimation;
  Timer? _growthTimer;
  String _selectedPlantType = 'monstera';
  
  // Available types based on asset folders
  final List<String> _availableTypes = ['aloe_vera', 'monstera', 'peace_lily'];

  // Soil area boundary (bottom 30% of screen roughly)
  static const double _soilHeightFactor = 0.35;

  @override
  void initState() {
    super.initState();
    
    // Background animation (time of day simulation)
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60), // Slow transition
    )..repeat(reverse: true);
    
    _skyAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_backgroundController);

    // Periodic growth update
    _growthTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _updateGrowth();
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _growthTimer?.cancel();
    super.dispose();
  }

  void _updateGrowth() {
    setState(() {
      for (int i = 0; i < _gardenPlants.length; i++) {
        final plant = _gardenPlants[i];
        if (plant.growthStage < 4) {
          double newProgress = plant.growthProgress + 0.02; // Slower growth for realism
          int newStage = plant.growthStage;
          
          if (newProgress >= 1.0) {
            newProgress = 0.0;
            newStage++;
          }
          
          _gardenPlants[i] = plant.copyWith(
            growthStage: newStage,
            growthProgress: newProgress,
          );
        }
      }
    });
  }

  void _addPlant(Offset position) {
    setState(() {
      _gardenPlants.add(GardenPlant(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        x: position.dx,
        y: position.dy,
        plantedTime: DateTime.now(),
        plantType: _selectedPlantType,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final soilTop = size.height * (1 - _soilHeightFactor);

    return Scaffold(
      body: GestureDetector(
        onTapDown: (details) {
          if (details.localPosition.dy > soilTop) {
            _addPlant(details.localPosition);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Sky Background (Image)
            Image.asset(
              'assets/images/sky.jpg',
              fit: BoxFit.cover,
            ),
            
            // Subtle animated tint for day/night feel on the image
            AnimatedBuilder(
              animation: _skyAnimation,
              builder: (context, child) {
                return Container(
                  color: Color.lerp(
                    Colors.black.withOpacity(0.4), // Night tint
                    Colors.transparent,             // Day tint
                    _skyAnimation.value,
                  ),
                );
              },
            ),

            // 2. Subtle Sun/Moon overlay
            AnimatedBuilder(
              animation: _skyAnimation,
              builder: (context, child) {
                return Positioned(
                  top: 100 + (1 - _skyAnimation.value) * 100,
                  right: 50,
                  child: Opacity(
                    opacity: 0.8,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color.lerp(Colors.orange, Colors.white, _skyAnimation.value)!.withOpacity(0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                        gradient: RadialGradient(
                          colors: [
                            Color.lerp(Colors.orangeAccent, Colors.white70, _skyAnimation.value)!,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // 3. Ground/Soil (Image)
            Positioned(
              top: soilTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: Image.asset(
                'assets/images/land.png',
                fit: BoxFit.cover,
              ),
            ),

            // 4. Plants
            ..._gardenPlants.map((plant) => PlantWidget(plant: plant)).toList(),

            // 5. Instruction Overlay
            if (_gardenPlants.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, color: Colors.white.withOpacity(0.6), size: 64),
                    const SizedBox(height: 16),
                    Text(
                      "Tap the soil to plant your garden",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

            // 6. Header
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your Digital Garden",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                        ),
                      ),
                      Text(
                        "${_gardenPlants.length} plants growing",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _gardenPlants.clear();
                      });
                    },
                  ),
                ],
              ),
            ),

            // 7. Plant Selection UI
            Positioned(
              bottom: 110,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _availableTypes.map((type) {
                    final isSelected = _selectedPlantType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPlantType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          type.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.green.shade900 : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

