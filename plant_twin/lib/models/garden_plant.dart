import 'dart:math';

class GardenPlant {
  final String id;
  final double x;
  final double y;
  final int growthStage; // 0: Seed, 1: Sprout, 2: Young, 3: Mature, 4: Flowering
  final double growthProgress; // 0.0 to 1.0 within the current stage
  final DateTime plantedTime;
  final double windOffset; // Randomized offset for swaying

  final String plantType; // Folder name in assets/

  GardenPlant({
    required this.id,
    required this.x,
    required this.y,
    this.growthStage = 0,
    this.growthProgress = 0.0,
    required this.plantedTime,
    required this.plantType,
    double? windOffset,
  }) : windOffset = windOffset ?? (Random().nextDouble() * pi * 2);

  GardenPlant copyWith({
    String? id,
    double? x,
    double? y,
    int? growthStage,
    double? growthProgress,
    DateTime? plantedTime,
    String? plantType,
    double? windOffset,
  }) {
    return GardenPlant(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      growthStage: growthStage ?? this.growthStage,
      growthProgress: growthProgress ?? this.growthProgress,
      plantedTime: plantedTime ?? this.plantedTime,
      plantType: plantType ?? this.plantType,
      windOffset: windOffset ?? this.windOffset,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'growthStage': growthStage,
      'growthProgress': growthProgress,
      'plantedTime': plantedTime.toIso8601String(),
      'plantType': plantType,
      'windOffset': windOffset,
    };
  }

  factory GardenPlant.fromJson(Map<String, dynamic> json) {
    return GardenPlant(
      id: json['id'],
      x: json['x'],
      y: json['y'],
      growthStage: json['growthStage'],
      growthProgress: json['growthProgress'],
      plantedTime: DateTime.parse(json['plantedTime']),
      plantType: json['plantType'] ?? 'monstera',
      windOffset: json['windOffset'],
    );
  }
}
