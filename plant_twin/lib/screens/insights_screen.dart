import 'package:flutter/material.dart';
import '../services/api_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _choresFuture;

  @override
  void initState() {
    super.initState();
    _choresFuture = _apiService.getAllChores();
  }

  Future<void> _refresh() async {
    setState(() {
      _choresFuture = _apiService.getAllChores();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7), // Light background
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            // 1. Custom Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Garden Insights",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Your daily digest & recommendations",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= CHORES =================
                    _sectionTitle("Daily Chores", Icons.checklist),
                    const SizedBox(height: 12),

                    FutureBuilder<List<dynamic>>(
                      future: _choresFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                           return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                           return Text("Error loading chores: ${snapshot.error}");
                        }
                        
                        final chores = snapshot.data ?? [];

                        if (chores.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade100),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 Container(
                                   padding: const EdgeInsets.all(8),
                                   decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                   child: const Icon(Icons.celebration, color: Colors.green),
                                 ),
                                 const SizedBox(width: 12),
                                 const Text(
                                  "All caught up! Great job.",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: chores.map((chore) {
                            return _buildChoreCard(chore);
                          }).toList(),
                        );
                      }
                    ),

                   const SizedBox(height: 32),

                  // ================= PRIORITY ALERTS (GRID) =================
                  _sectionTitle("Priority Alerts", Icons.warning_amber_rounded),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Grid for Alerts
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85, // Adjust for height
              children: [
                _alertCard(
                  title: "High Heat",
                  subtitle: "Expected tomorrow.",
                  body: "Increase irrigation.",
                  color: Colors.orange,
                  tag: "WARNING",
                  icon: Icons.wb_sunny,
                ),
                _alertCard(
                  title: "Fungal Risk",
                  subtitle: "High humidity.",
                  body: "Improve airflow.",
                  color: Colors.red,
                  tag: "CRITICAL",
                  icon: Icons.water,
                ),
                 _alertCard(
                  title: "Optimal Growth",
                  subtitle: "Perfect conditions.",
                  body: "Maximize light.",
                  color: Colors.green,
                  tag: "GOOD",
                  icon: Icons.verified,
                ),
                 Container(
                   decoration: BoxDecoration(
                     color: Colors.grey.shade50,
                     borderRadius: BorderRadius.circular(20),
                     border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
                   ),
                   child: const Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Icons.add_circle_outline, color: Colors.grey, size: 30),
                         SizedBox(height: 8),
                         Text("No more alerts", style: TextStyle(color: Colors.grey)),
                       ],
                     ),
                   ),
                 ),
              ],
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    ),
    );
  }
  

  // ================= UI COMPONENTS =================

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
        ),
      ],
    );
  }

  Widget _buildChoreCard(Map<String, dynamic> chore) {
      Color priorityColor = chore['priority'] == 'Urgent' ? Colors.red : (chore['priority'] == 'High' ? Colors.orange : Colors.green);
      IconData icon = chore['icon'] == 'water_drop' ? Icons.water_drop : (chore['icon'] == 'home' ? Icons.home : Icons.notifications);
      String plantName = chore['plant_name'] ?? "Unknown Plant";
      
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
                              Text(plantName, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(chore['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(chore['description'], style: const TextStyle(color: Colors.black54, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(chore['status'], style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                      ),
                  ),
              ],
          ),
      );
  }

  Widget _alertCard({
    required String title,
    required String subtitle,
    required String body,
    required Color color,
    required String tag,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
           const SizedBox(height: 8),
           Text(
            body,
            style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
