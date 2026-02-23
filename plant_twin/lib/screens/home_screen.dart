import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../widgets/plant_widget.dart';
import '../services/api_service.dart';
import '../models/user_profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Future<List<Plant>>? _plantsFuture;
  Future<UserProfile>? _profileFuture;
  late AnimationController _backgroundController;
  late Animation<double> _skyAnimation;
  final ApiService _apiService = ApiService();

  // Soil area boundary (bottom 35% of screen roughly)
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
    _loadData();
  }

  void _loadData() {
    setState(() {
      _plantsFuture = _apiService.getPlants();
      _profileFuture = _apiService.getUserProfile();
    });
  }

  void _loadPlants() {
    setState(() {
      _plantsFuture = _apiService.getPlants();
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final soilTop = size.height * (1 - _soilHeightFactor);

    return Scaffold(
      body: Stack(
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

          // 4. Plants from Backend
          FutureBuilder<List<Plant>>(
            future: _plantsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.white60, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        "Couldn't connect to your garden.",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      TextButton(
                        onPressed: _loadPlants,
                        child: const Text("Try Again", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }
              
              final plants = snapshot.data ?? [];
              
              if (plants.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco_outlined, color: Colors.white.withOpacity(0.6), size: 64),
                      const SizedBox(height: 16),
                      Text(
                        "Your garden is empty.\nAdd some plants from the '+' tab!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Stack(
                children: plants.map((plant) => PlantWidget(plant: plant)).toList(),
              );
            },
          ),

          // 5. Header
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: FutureBuilder<List<Plant>>(
              future: _plantsFuture,
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<UserProfile>(
                          future: _profileFuture,
                          builder: (context, profileSnapshot) {
                            final name = profileSnapshot.data?.fullName?.split(' ').first ?? "Your";
                            return Text(
                              "$name's Indoor Garden",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                              ),
                            );
                          },
                        ),
                        Text(
                          "$count plants growing",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadPlants,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
