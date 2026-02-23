import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui'; // For ImageFilter
import '../services/api_service.dart';
import '../models/user_profile.dart';
import 'login_screen.dart';
import 'package:plant_twin/theme/app_theme.dart';
import '../main.dart'; // Access themeNotifier

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  UserProfile? _profile;
  bool _isEditing = false;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    try {
      final profile = await _apiService.getUserProfile();
      setState(() {
        _profile = profile;
        _nameController.text = profile.fullName ?? "";
        _typeController.text = profile.gardenType ?? "";
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final updatedProfile = await _apiService.updateProfile(_nameController.text, _typeController.text);
      setState(() {
        _profile = updatedProfile;
        _isEditing = false;
        _isLoading = false;
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
    } catch (e) {
      setState(() => _isLoading = false);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  void _logout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _toggleTheme(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profile == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Failed to load profile", style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                   setState(() => _isLoading = true);
                   _loadProfile();
                },
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final stats = _profile!.stats;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F5F0),
      body: CustomScrollView(
        slivers: [
          // 1. Premium Sliver Header
          SliverPersistentHeader(
            delegate: _ProfileHeaderDelegate(
              profile: _profile,
              isEditing: _isEditing,
              nameController: _nameController,
              typeController: _typeController,
              onEditToggle: () {
                if (_isEditing) _saveProfile();
                else setState(() => _isEditing = true);
              },
            ),
            pinned: true,
          ),

          // 2. Content Body (Overlapping)
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121212) : const Color(0xFFF2F5F0), 
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              transform: Matrix4.translationValues(0, -30, 0), // Overlap effect
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // Stats Section
                    Text("Garden Analytics", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                    _buildStatsGrid(stats, cardColor, textColor, subTextColor),

                    // Health Status - Gap Removed/Reduced
                    const SizedBox(height: 12),
                    _buildHealthStatusCard(stats),

                    const SizedBox(height: 30),

                    // Settings (Dark Mode)
                    Text("Preferences", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: SwitchListTile(
                        value: isDark,
                        onChanged: _toggleTheme,
                        title: Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.dark_mode_rounded, color: Colors.indigo),
                        ),
                        activeColor: AppTheme.primaryGreen,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded, color: Colors.white),
                        label: const Text("Log Out"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(GardenStats stats, Color cardColor, Color textColor, Color subTextColor) {
    return Row(
      children: [
        Expanded(child: _statCard("Total Plants", "${stats.totalPlants}", Icons.local_florist_rounded, Colors.green, cardColor, textColor, subTextColor)),
        const SizedBox(width: 12),
        Expanded(child: _statCard("Streak", "${stats.streakDays} Days", Icons.whatshot_rounded, Colors.orange, cardColor, textColor, subTextColor)),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 14, color: subTextColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildHealthStatusCard(GardenStats stats) {
    final isGood = stats.gardenStatus == "Good";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGood 
             ? [const Color(0xFF43A047), const Color(0xFF66BB6A)] 
             : [const Color(0xFFEF6C00), const Color(0xFFFFA726)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: (isGood ? Colors.green : Colors.orange).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(isGood ? Icons.thumb_up_rounded : Icons.warning_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Garden Health: ${stats.gardenStatus}",
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  isGood ? "Great job! Your plants are thriving." : "Some plants need attention.",
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Header Delegate ---
class _ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  final UserProfile? profile;
  final bool isEditing;
  final TextEditingController nameController;
  final TextEditingController typeController;
  final VoidCallback onEditToggle;

  const _ProfileHeaderDelegate({
    required this.profile,
    required this.isEditing,
    required this.nameController,
    required this.typeController,
    required this.onEditToggle,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = shrinkOffset / maxExtent;
    
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image - Use a high-quality abstract nature image
          Image.network(
            "https://images.unsplash.com/photo-1470058869958-2a77ade41c02?q=80&w=2070&auto=format&fit=crop",
            fit: BoxFit.cover,
          ),
          
          // Blur / Glassmorphism
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5 * progress, sigmaY: 5 * progress),
            child: Container(
              color: Colors.black.withOpacity(0.3 + (progress * 0.4)),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), // More padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start, // Align left
                children: [
                  // Top Bar (Title & Edit) - Removed to simplify, or keep if needed?
                  // Let's keep a Edit button but maybe minimal.
                  if (shrinkOffset < 150)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       const SizedBox(), // Spacer
                       IconButton(
                        onPressed: onEditToggle,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: Icon(isEditing ? Icons.check : Icons.edit, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Avatar & Info - Centered or Left? Left is better for profile.
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2), // Border
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: CircleAvatar(
                          radius: (40 - (progress * 15)).clamp(20, 40).toDouble(),
                          backgroundColor: Colors.white,
                          backgroundImage: NetworkImage("https://ui-avatars.com/api/?name=${profile?.fullName}&background=2E7D32&color=fff&size=200"),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isEditing) ...[
                                TextField(
                                  controller: nameController,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                  decoration: const InputDecoration(hintText: "Full Name", border: InputBorder.none, isDense: true),
                                ),
                                TextField(
                                  controller: typeController,
                                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                                  decoration: const InputDecoration(hintText: "Garden Type", border: InputBorder.none, isDense: true),
                                ),
                            ] else ...[
                                Text(
                                  profile?.fullName ?? "Gardener",
                                  style: TextStyle(
                                    color: Colors.white, 
                                    fontSize: (28 - (progress * 8)).clamp(20, 28).toDouble(), 
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)]
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (shrinkOffset < 100)
                                Text(
                                  "${profile?.gardenType ?? 'Home'} Garden",
                                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Spacing compensation
                  if (shrinkOffset >= 150) const SizedBox(height: 10), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 280; // Reduced height
  @override
  double get minExtent => 120;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
