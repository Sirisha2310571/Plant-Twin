import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import '../models/plant.dart';
import '../screens/plant_detail_screen.dart';
import '../theme/app_theme.dart';

class PlantWidget extends StatefulWidget {
  final Plant plant;
  final double windStrength;

  const PlantWidget({
    super.key,
    required this.plant,
    this.windStrength = 1.0,
  });

  @override
  State<PlantWidget> createState() => _PlantWidgetState();
}

class _PlantWidgetState extends State<PlantWidget> with SingleTickerProviderStateMixin {
  late AnimationController _swayController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _swayController.dispose();
    super.dispose();
  }

  String _getStageName(int stage) {
    const stages = ["Seedling", "Vegetative", "Budding", "Flowering", "Mature"];
    if (stage < 0) return stages[0];
    if (stage >= stages.length) return stages.last;
    return stages[stage];
  }

  @override
  Widget build(BuildContext context) {
    final plantFolder = widget.plant.species; 
    final assetPath = 'assets/$plantFolder/stage${widget.plant.growthStage + 1}.png';
    final windOffset = (widget.plant.id * 0.77) % (pi * 2);
    final scale = 0.8 + (widget.plant.growthStage * 0.05);

    return Positioned(
      left: widget.plant.x,
      top: widget.plant.y - 100,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlantDetailScreen(
                  plantId: widget.plant.id,
                  plantName: widget.plant.name,
                ),
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Nickname Label (Shows on hover)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                top: _isHovered ? -60 : -40,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isHovered ? 1.0 : 0.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.plant.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getStageName(widget.plant.growthStage),
                              style: TextStyle(
                                color: AppTheme.lightGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // The Plant
              AnimatedBuilder(
                animation: _swayController,
                builder: (context, child) {
                  final sway = sin(_swayController.value * pi * 2 + windOffset) * 0.03 * widget.windStrength;
                  
                  return Transform.scale(
                    scale: _isHovered ? scale * 1.1 : scale, // Subtle hover scale
                    alignment: Alignment.bottomCenter,
                    child: Transform.rotate(
                      angle: sway,
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(
                        assetPath,
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.eco, color: Colors.green, size: 40);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
