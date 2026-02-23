import 'package:flutter/material.dart';
import 'dart:math';
import '../models/garden_plant.dart';

class PlantWidget extends StatefulWidget {
  final GardenPlant plant;
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

  @override
  Widget build(BuildContext context) {
    // Stage logic: folders have stage1.png to stage5.png
    // model growthStage is 0-4
    final assetPath = 'assets/${widget.plant.plantType}/stage${widget.plant.growthStage + 1}.png';
    
    // Scale animation within a stage (from 0.8 to 1.1)
    final scale = 0.8 + (widget.plant.growthProgress * 0.3);

    return Positioned(
      left: widget.plant.x - 50,
      top: widget.plant.y - 120, // Adjusted for image height
      child: AnimatedBuilder(
        animation: _swayController,
        builder: (context, child) {
          final sway = sin(_swayController.value * pi * 2 + widget.plant.windOffset) * 0.04 * widget.windStrength;
          
          return Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: Transform.rotate(
              angle: sway,
              alignment: Alignment.bottomCenter,
              child: Image.asset(
                assetPath,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.eco, color: Colors.green, size: 40);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
