import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/plant.dart';
import '../models/plant_log.dart';
import '../services/api_service.dart';
import 'package:plant_twin/theme/app_theme.dart';
import 'dart:ui'; // For ImageFilter

class PlantDetailScreen extends StatefulWidget {
  final int plantId;
  final String plantName;

  const PlantDetailScreen({super.key, required this.plantId, required this.plantName});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  final ApiService _apiService = ApiService();
  late Future<Plant> _plantFuture;
  late Future<Map<String, dynamic>> _profileFuture;
  late Future<List<dynamic>> _choresFuture; // New
  final ImagePicker _picker = ImagePicker();
  String _currentLocation = "Indoor"; // Default

  @override
  void initState() {
    super.initState();
    _refreshPlant();
  }

  void _refreshPlant() {
    setState(() {
      _plantFuture = _apiService.getPlantDetails(widget.plantId).then((plant) {
          // Initialize location from plant data (requires API update to return location in Plant model, 
          // or we can fetch it separately, but let's assume Plant model has it or we default)
          // For now, let's assume we can get it or default.
          // Since we didn't update Dart Plant model yet, we might miss it.
          // Let's rely on checking chores or just default for now, then update model.
          return plant;
      });
      _profileFuture = _apiService.getPlantProfile(widget.plantId);
      _choresFuture = _apiService.getPlantChores(widget.plantId);
    });
  }

  void _updateLocation(bool isIndoor) async {
      String newLoc = isIndoor ? "Indoor" : "Outdoor";
      try {
          await _apiService.updatePlantLocation(widget.plantId, newLoc);
          setState(() => _currentLocation = newLoc);
          _refreshPlant(); // Refresh chores based on new location
      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update location: $e")));
      }
  }

  void _deletePlant() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Plant?"),
        content: Text("Are you sure you want to remove ${widget.plantName} from your garden? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              try {
                await _apiService.deletePlant(widget.plantId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plant deleted.")));
                  Navigator.pop(context); // Go back to Plants Screen
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _waterPlant() async {
    try {
      final msg = await _apiService.waterPlant(widget.plantId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _refreshPlant();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Watering failed: $e")));
    }
  }

  void _checkHealth() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    if (!mounted) return;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _apiService.checkPlantHealth(widget.plantId, image);
      if (!mounted) return;
      Navigator.pop(context); // Hide loading

      bool isHealthy = result['is_healthy'] ?? false;
      String diagnosis = result['diagnosis'] ?? "Unknown";
      double confidence = (result['confidence'] ?? 0.0) * 100;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(isHealthy ? Icons.check_circle : Icons.warning, color: isHealthy ? Colors.green : Colors.red),
              const SizedBox(width: 10),
              const Text("Health Check"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Diagnosis: $diagnosis", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text("Confidence: ${confidence.toStringAsFixed(1)}%"),
              const SizedBox(height: 16),
              Text(
                isHealthy 
                  ? "Your plant looks healthy! Keep up the good work." 
                  : "It seems your plant might be affected. Consider isolating it and checking care guides.",
                style: const TextStyle(color: Colors.black87),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Hide loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Analysis failed: $e")));
      }
    }
  }

  String _getStageName(int stage) {
    const stages = ["Seedling", "Vegetative", "Budding", "Flowering", "Mature"];
    if (stage < 0) return stages[0];
    if (stage >= stages.length) return stages.last;
    return stages[stage];
  }

  void _logGrowth() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    final TextEditingController heightController = TextEditingController();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Log Growth"),
        content: TextField(
          controller: heightController,
          decoration: const InputDecoration(labelText: "Height (cm)", border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final double? height = double.tryParse(heightController.text);
              if (height == null) return;
              
              Navigator.pop(context); // Close dialog
              try {
                await _apiService.addPlantLog(widget.plantId, height, image);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Growth Logged!")));
                _refreshPlant();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  void _updateGrowthStage(int currentStageIndex) {
    final List<String> stages = ["Seedling", "Vegetative", "Budding", "Flowering", "Mature"];
    int selectedIndex = currentStageIndex;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Update Stage"),
            content: DropdownButton<int>(
              value: selectedIndex,
              isExpanded: true,
              items: List.generate(stages.length, (i) => DropdownMenuItem(value: i, child: Text(stages[i]))),
              onChanged: (val) => setState(() => selectedIndex = val!),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _apiService.updateGrowthStage(widget.plantId, selectedIndex.toString());
                    Navigator.pop(context);
                    _refreshPlant();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
                  }
                },
                child: const Text("Update"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F0), // Soft background
      body: FutureBuilder<Plant>(
        future: _plantFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData) {
            return const Center(child: Text("Plant not found"));
          }

          final plant = snapshot.data!;
          final state = plant.plantState;
          final List<PlantLog> logs = plant.logs ?? [];

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // 1. Immersive Header
                  SliverAppBar(
                    expandedHeight: 320.0,
                    pinned: true,
                    backgroundColor: AppTheme.primaryGreen,
                    stretch: true,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      stretchModes: const [StretchMode.zoomBackground],
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                           plant.imagePath != null
                              // Use API service to construct full URL
                              ? Image.network(
                                  _apiService.getImageUrl(plant.imagePath!), 
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(color: Colors.green.shade200),
                                )
                              : Container(color: Colors.green.shade200),
                           // Gradient Overlay
                           Container(
                             decoration: const BoxDecoration(
                               gradient: LinearGradient(
                                 begin: Alignment.topCenter,
                                 end: Alignment.bottomCenter,
                                 colors: [Colors.black12, Colors.black54],
                               ),
                             ),
                           ),
                           // Title on Image
                           Positioned(
                             bottom: 20,
                             left: 20,
                             right: 20,
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   plant.name,
                                   style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                 ),
                                 Text(
                                   plant.species,
                                   style: const TextStyle(color: Colors.white70, fontSize: 16),
                                 ),
                               ],
                             ),
                           )
                        ],
                      ),
                    ),
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    actions: [
                       Container(
                        margin: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white),
                          onPressed: _deletePlant,
                        ),
                      ),
                    ],
                  ),

                  // 2. Content Body (Overlapping)
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F5F0), 
                        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                      transform: Matrix4.translationValues(0, -20, 0), // Overlap effect
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 100), // Extra bottom padding for buttons
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Vitals Grid
                            Row(
                              children: [
                                Expanded(child: _vitalCard("Health", "${state?.healthScore.toInt()}%", Icons.favorite, Colors.green)),
                                const SizedBox(width: 12),
                                Expanded(child: _vitalCard("Water", state != null && state.waterStress < 0.3 ? "Good" : "Needs Water", Icons.water_drop, Colors.blue)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _vitalCard("Stage", _getStageName(plant.growthStage), Icons.eco, Colors.orange)),
                                const SizedBox(width: 12),
                                Expanded(child: _vitalCard("Light", "Optimal", Icons.wb_sunny, Colors.amber)), // Placeholder
                              ],
                            ),
                            
                            const SizedBox(height: 30),

                            // Chores Section
                            Text("Today's Tasks", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            FutureBuilder<List<dynamic>>(
                                future: _choresFuture,
                                builder: (context, snapshot) {
                                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                        return Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                            child: Row(children: const [
                                                Icon(Icons.check_circle, color: Colors.green), 
                                                SizedBox(width: 10), 
                                                Text("All caught up! No pending tasks.")
                                            ]),
                                        );
                                    }
                                    return Column(
                                        children: snapshot.data!.map((chore) => _buildChoreCard(chore)).toList(),
                                    );
                                },
                            ),
                            
                            const SizedBox(height: 30),

                            // Location Toggle
                            Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                 child: Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                     children: [
                                         const Text("Location", style: TextStyle(fontWeight: FontWeight.bold)),
                                         Row(
                                             children: [
                                                 const Text("Outdoor"),
                                                 Switch(
                                                     value: _currentLocation == "Indoor", 
                                                     onChanged: (val) => _updateLocation(val),
                                                     activeColor: AppTheme.primaryGreen,
                                                 ),
                                                 const Text("Indoor"),
                                             ],
                                         )
                                     ],
                                 ),
                            ),

                            const SizedBox(height: 30),

                            // Requirements Section
                            FutureBuilder<Map<String, dynamic>>(
                              future: _profileFuture,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                                return _buildRequirementsCard(snapshot.data!);
                              },
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // Growth Chart
                            Text("Growth History", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            _buildGrowthChart(logs),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 3. Floating Action Controls
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left Actions (Water, Log, Stage)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _actionButton(Icons.water_drop, "Water", Colors.blue, _waterPlant),
                          const SizedBox(width: 12),
                          _verticalLine(),
                          const SizedBox(width: 12),
                          _actionButton(Icons.camera_alt, "Log", Colors.purple, _logGrowth),
                          const SizedBox(width: 12),
                          _verticalLine(),
                          const SizedBox(width: 12),
                          _actionButton(Icons.timeline, "Stage", Colors.orange, () => _updateGrowthStage(plant.growthStage)),
                        ],
                      ),
                    ),

                    // Right Prominent Action (Check Health)
                    FloatingActionButton.extended(
                      onPressed: _checkHealth,
                      backgroundColor: AppTheme.primaryGreen,
                      elevation: 4,
                      icon: const Icon(Icons.health_and_safety, color: Colors.white),
                      label: const Text("Check", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _vitalCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _verticalLine() => Container(height: 30, width: 1, color: Colors.grey.shade200);

  // ... (Keep existing _buildRequirementsCard and _reqRow and _buildGrowthChart as they were fine, just re-styled container if needed)

  Widget _buildRequirementsCard(Map<String, dynamic> profileData) {
     // Copied from previous logic, wrapped in new container style
     if (!profileData.containsKey('profile')) return const SizedBox.shrink();
     final profile = profileData['profile'];
     final species = profileData['species'] ?? "Unknown value";

     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text("Optimal Conditions", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
         const SizedBox(height: 15),
         Container(
           padding: const EdgeInsets.all(20),
           decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.circular(24),
             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
           ),
           child: Column(
             children: [
                _reqRow("Temp", profile['Room_Temperature_C'], "°C"),
                _reqRow("Humidity", profile['Humidity_%'], "%"),
                _reqRow("Moisture", profile['Soil_Moisture_%'], "%"),
             ],
           ),
         ),
       ],
     );
  }

  Widget _reqRow(String label, dynamic data, String unit) { 
     // Simplified row
     String valueStr = "Unknown";
     if (data is Map) {
         final min = data['optimal_min'] ?? data['min'];
         final max = data['optimal_max'] ?? data['max'];
         if (min != null && max != null) valueStr = "${min.toInt()}-${max.toInt()}$unit";
     }
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 8),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           Text(label, style: const TextStyle(color: Colors.grey)),
           Text(valueStr, style: const TextStyle(fontWeight: FontWeight.bold)),
         ],
       ),
     );
  }

  Widget _buildGrowthChart(List<PlantLog> logs) {
    if (logs.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        alignment: Alignment.center,
        child: const Text("No growth data yet", style: TextStyle(color: Colors.grey)),
      );
    }
  
    // Sort logs by date just in case
    logs.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10)],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: logs.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.height)).toList(),
              isCurved: true,
              color: AppTheme.primaryGreen,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: AppTheme.primaryGreen.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildChoreCard(Map<String, dynamic> chore) {
      Color priorityColor = chore['priority'] == 'Urgent' ? Colors.red : (chore['priority'] == 'High' ? Colors.orange : Colors.green);
      IconData icon = chore['icon'] == 'water_drop' ? Icons.water_drop : (chore['icon'] == 'home' ? Icons.home : Icons.notifications);
      
      return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border(left: BorderSide(color: priorityColor, width: 4)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
          ),
          child: Row(
              children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: priorityColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(icon, color: priorityColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(chore['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(chore['description'], style: const TextStyle(color: Colors.black54, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(chore['status'], style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                      ),
                  ),
                  if (chore['id'] == 'water')
                  IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.grey),
                      onPressed: _waterPlant, // Completes task
                  )
              ],
          ),
      );
  }
}
