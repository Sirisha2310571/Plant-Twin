import 'dart:io';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'package:plant_twin/theme/app_theme.dart';

class AddPlantScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  const AddPlantScreen({super.key, this.onSuccess});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  int _selectedStage = 0;
  String _selectedSpecies = 'unknown';
  final List<String> _speciesList = [
    'unknown', 'anthurium', 'begonia', 'boston_fern', 'calathea', 'dumb_cane',
    'iron_cross_begonia', 'pothos', 'rattlesnake_plant', 'schefflera',
    'snake_plant', 'tradescantia', 'zz_plant', 'aloe_vera', 'chinese',
    'monstera', 'peace_lily', 'rubber'
  ];

  final List<String> _stageNames = [
    "Seedling", "Vegetative", "Budding", "Flowering", "Mature"
  ];
  final _apiService = ApiService();
  XFile? _imageFile;
  final ImagePicker picker = ImagePicker();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future _pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final size = MediaQuery.of(context).size;
      // Random position in soil area (bottom 35% of screen)
      // We'll use a slightly safer range to avoid plants being cut off
      final double x = 20 + (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0 * (size.width - 160);
      final double soilTop = size.height * 0.65;
      final double y = soilTop + 20 + ((DateTime.now().microsecondsSinceEpoch % 1000) / 1000.0 * (size.height * 0.2));

      await _apiService.createPlant(
        _nameController.text,
        _selectedSpecies,
        _imageFile!,
        growthStage: _selectedStage,
        x: x,
        y: y,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Plant added successfully!")),
        );
        // Clean up form
        _nameController.clear();
        setState(() => _imageFile = null);
        
        // Navigate via callback if provided, else pop or go home
        if (widget.onSuccess != null) {
             widget.onSuccess!();
        } else {
             // Fallback if used outside tab view
             try {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                   // If we can't pop, we might be at root tab. 
                   // Ideally MainNav handles this. 
                   // But let's avoid pushNamedAndRemoveUntil('/')
                }
             } catch (e) {
               // ignore
             }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F0), // Soft mint background
      appBar: AppBar(
        title: const Text("New Addition", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Let's grow your jungle!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Image Picker
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt, color: AppTheme.primaryGreen),
                          title: const Text("Take a Photo"),
                          onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library, color: AppTheme.primaryGreen),
                          title: const Text("Choose from Gallery"),
                          onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
                child: Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              kIsWeb 
                                  ? Image.network(_imageFile!.path, fit: BoxFit.cover) 
                                  : Image.file(File(_imageFile!.path), fit: BoxFit.cover),
                              Container(
                                color: Colors.black26,
                                child: const Center(child: Icon(Icons.edit, color: Colors.white, size: 40)),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_a_photo, size: 40, color: AppTheme.primaryGreen),
                            ),
                            const SizedBox(height: 16),
                            const Text("Tap to add plant photo", style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Form Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Nickname",
                        hintText: "e.g. Mr. Green",
                        prefixIcon: const Icon(Icons.edit, color: AppTheme.primaryGreen),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      validator: (value) => value!.isEmpty ? "Give your plant a name" : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedSpecies,
                      decoration: InputDecoration(
                        labelText: "Plant Species",
                        prefixIcon: const Icon(Icons.grass, color: AppTheme.primaryGreen),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: _speciesList.map((s) {
                        String label = s == 'unknown' 
                            ? "Auto-Identify (AI)" 
                            : s.replaceAll('_', ' ').split(' ').map((str) => str.isNotEmpty ? str[0].toUpperCase() + str.substring(1) : str).join(' ');
                        return DropdownMenuItem(
                          value: s,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedSpecies = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedStage,
                      decoration: InputDecoration(
                        labelText: "Growth Stage",
                        prefixIcon: const Icon(Icons.show_chart, color: AppTheme.primaryGreen),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: [0, 1, 2, 3, 4].map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(_stageNames[s]),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedStage = val!),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Our smart AI will identify your plant species automatically!",
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: AppTheme.primaryGreen.withOpacity(0.4),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Add to Garden", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 120), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}
