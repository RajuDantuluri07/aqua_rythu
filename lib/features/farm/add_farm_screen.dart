import 'package:flutter/material.dart';
import 'package:aqua_rythu/routes/app_routes.dart';

class AddFarmScreen extends StatefulWidget {
  const AddFarmScreen({super.key});

  @override
  State<AddFarmScreen> createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends State<AddFarmScreen> {

  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createFarm() async {
    final farmName = _farmNameController.text.trim();

    if (farmName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Farm name is required"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simulate API call to create farm
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() => _isLoading = false);

    Navigator.pushNamed(context, AppRoutes.addPond);
  }

  @override
  void dispose() {
    _farmNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 20),

              /// STEP TEXT
              const Center(
                child: Text(
                  "STEP 2 OF 3",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// TITLE
              const Text(
                "Let's set up your farm",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1F36),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "Provide some basic details to get started with your Aqua Rythu aquaculture management.",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 30),

              /// FARM NAME
              const Text(
                "Farm Name *",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _farmNameController,
                decoration: const InputDecoration(
                  hintText: "e.g. Sunshine Shrimp Farm",
                ),
              ),

              const SizedBox(height: 20),

              /// LOCATION
              const Text(
                "Location (Optional)",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  hintText: "Enter district or village",
                  suffixIcon: Icon(Icons.location_on_outlined),
                ),
              ),

              const Spacer(),

              /// BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createFarm,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Create Farm",
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              /// FOOTER TEXT
              const Center(
                child: Text(
                  "By continuing, you agree to our terms of service and management protocols.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}