import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_plan_provider.dart'; // ✅ IMPORTANT

class AddPondScreen extends ConsumerStatefulWidget {
  const AddPondScreen({super.key});

  @override
  ConsumerState<AddPondScreen> createState() => _AddPondScreenState();
}

class _AddPondScreenState extends ConsumerState<AddPondScreen> {
  final TextEditingController _pondNameController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _seedController = TextEditingController();
  final TextEditingController _plSizeController = TextEditingController();

  bool _isLoading = false;

  Future<void> _finishSetup() async {
    final name = _pondNameController.text.trim();
    final area = _areaController.text.trim();
    final seed = _seedController.text.trim();
    final plSize = _plSizeController.text.trim();

    if (name.isEmpty || area.isEmpty || seed.isEmpty || plSize.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final selectedFarmId = ref.read(farmProvider).selectedId;

    /// ✅ CREATE POND
    ref.read(farmProvider.notifier).addPond(
      selectedFarmId,
      name,
      double.parse(area),
      seedCount: int.parse(seed),
      plSize: int.parse(plSize),
    );

    /// 🔥 AUTO CREATE FEED PLAN
    final newPondId = ref.read(farmProvider)
        .currentFarm!
        .ponds
        .last
        .id;

    ref.read(feedPlanProvider.notifier).createPlan(
      pondId: newPondId,
      seedCount: int.parse(seed),
      plSize: int.parse(plSize),
    );

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
    _seedController.dispose();
    _plSizeController.dispose();
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

              const Center(
                child: Text(
                  "STEP 3 OF 3",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                "Create Pond",
                style: Theme.of(context).textTheme.headlineLarge,
              ),

              const SizedBox(height: 10),

              const Text(
                "Enter pond details to generate automatic feeding plan.",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 30),

              const Text("Pond Name *"),
              TextField(controller: _pondNameController),

              const SizedBox(height: 20),

              const Text("Pond Size (Acres) *"),
              TextField(
                controller: _areaController,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 20),

              const Text("PL Count *"),
              TextField(
                controller: _seedController,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 20),

              const Text("PL Size *"),
              TextField(
                controller: _plSizeController,
                keyboardType: TextInputType.number,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _finishSetup,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Pond & Generate Feed Plan"),
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