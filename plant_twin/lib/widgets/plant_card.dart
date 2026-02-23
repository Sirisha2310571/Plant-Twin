import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../theme/app_theme.dart';

class PlantCard extends StatelessWidget {
  final Plant plant;
  final String? imageUrl;

  const PlantCard({
    super.key,
    required this.plant,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final health = plant.plantState?.healthScore ?? 100.0;
    
    // Determine status color - Only show if CRITICAL
    Color? statusColor;
    String? statusText;
    
    if (health < 50) {
      statusColor = Colors.red;
      statusText = "Critical";
    } 
    // Removed "Attention" state as per user request.

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // 1. Plant Image (Larger, Rounded)
            Hero(
              tag: "plant_${plant.id}",
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.green.shade50,
                ),
                clipBehavior: Clip.antiAlias, // Ensure image stays inside rounded corners
                child: imageUrl != null
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(Icons.park, size: 40, color: Colors.green.shade200),
                          );
                        },
                      )
                    : Center(
                        child: Icon(Icons.park, size: 40, color: Colors.green.shade200),
                      ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 2. Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    plant.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plant.species,
                    style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  
                  // 3. Stats Row (Badges)
                  if (statusText != null && statusColor != null)
                    _statusBadge(statusText!, statusColor!),
                ],
              ),
            ),

            // 4. Action Arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}
