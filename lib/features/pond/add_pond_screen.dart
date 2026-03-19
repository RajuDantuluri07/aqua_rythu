import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import '../farm/farm_provider.dart';

class AddPondScreen extends ConsumerStatefulWidget {
  const AddPondScreen({super.key});

  @override
  ConsumerState<AddPondScreen> createState() => _AddPondScreenState();
}

class _AddPondScreenState extends ConsumerState<AddPondScreen> {
  final TextEditingController _pondNameController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  bool _isLoading = false;

  Future<void> _finishSetup() async {
    final name = _pondNameController.text.trim();
    final area = _areaController.text.trim();

    if (name.isEmpty || area.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simulate API call/Network delay
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // 🔥 Add pond to the currently selected farm
    final selectedFarmId = ref.read(farmProvider).selectedId;
    ref.read(farmProvider.notifier).addPond(selectedFarmId, name, double.parse(area));

    // Complete setup and navigate to Dashboard, removing setup history
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.dashboard,
      (route) => false,
    );
  }

  @override
  void dispose() {
    _pondNameController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Step Indicator
              const Center(
                child: Text(
                  "STEP 3 OF 3",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Text(
                "Add your first pond",
                style: Theme.of(context).textTheme.headlineLarge,
              ),

              const SizedBox(height: 10),

              const Text(
                "Enter details for your first pond to initialize your dashboard.",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 30),

              // Pond Name
              const Text(
                "Pond Name *",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pondNameController,
                decoration: const InputDecoration(hintText: "e.g. Pond A1"),
              ),

              const SizedBox(height: 20),

              // Area
              const Text(
                "Pond Area (Acres) *",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _areaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: "e.g. 2.5"),
              ),

              const Spacer(),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _finishSetup,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Finish Setup",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}