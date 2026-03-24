import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'water_provider.dart';

class WaterTestScreen extends ConsumerStatefulWidget {
  final String pondId;
  const WaterTestScreen({super.key, required this.pondId});

  @override
  ConsumerState<WaterTestScreen> createState() => _WaterTestScreenState();
}

class _WaterTestScreenState extends ConsumerState<WaterTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ammoniaController = TextEditingController();
  final TextEditingController _phController = TextEditingController();
  final TextEditingController _doController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _salinityController = TextEditingController();
  final TextEditingController _alkalinityController = TextEditingController();

  @override
  void dispose() {
    _phController.dispose();
    _doController.dispose();
    _tempController.dispose();
    _salinityController.dispose();
    _alkalinityController.dispose();
    _ammoniaController.dispose();
    super.dispose();
  }

  void _saveWaterTest() {
    if (_formKey.currentState?.validate() ?? false) {
      final ph = double.tryParse(_phController.text) ?? 0;
      final doVal = double.tryParse(_doController.text) ?? 0;
      final temp = double.tryParse(_tempController.text) ?? 0;
      final sal = double.tryParse(_salinityController.text) ?? 0;
      final alk = double.tryParse(_alkalinityController.text) ?? 0;
      final ammonia = double.tryParse(_ammoniaController.text) ?? 0;
      final doc = ref.read(docProvider(widget.pondId));

      ref.read(waterProvider(widget.pondId).notifier).addLog(
        doc: doc,
        ph: ph,
        dissolvedOxygen: doVal,
        temperature: temp,
        salinity: sal,
        alkalinity: alk,
        ammonia: ammonia,
        nitrite: 0,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text("Water metrics logged successfully", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.teal.shade700,
          margin: const EdgeInsets.all(16),
          elevation: 6,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(docProvider(widget.pondId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Water Quality Test", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 56, bottom: 40, left: 24, right: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade600, Colors.cyan.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.water_drop_rounded, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "POND 1 • DOC $doc",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 16),
                      child: Text(
                        "Test Parameters",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildInput("pH Level", _phController, Icons.opacity_rounded, hint: "e.g. 7.5", target: "7.5 - 8.5"),
                          const SizedBox(height: 24),
                          _buildInput("Dissolved Oxygen", _doController, Icons.water, suffix: "ppm", hint: "e.g. 5.2", target: "> 4.0 ppm"),
                          const SizedBox(height: 24),
                          _buildInput("Temperature", _tempController, Icons.thermostat_rounded, suffix: "°C", hint: "e.g. 28", target: "28 - 32 °C"),
                          const SizedBox(height: 24),
                          _buildInput("Salinity", _salinityController, Icons.blur_on_rounded, suffix: "ppt", hint: "e.g. 15", target: "10 - 25 ppt"),
                          const SizedBox(height: 24),
                          _buildInput("Alkalinity", _alkalinityController, Icons.science_outlined, suffix: "ppm", hint: "e.g. 120", target: "100 - 150 ppm"),
                          const SizedBox(height: 24),
                          _buildInput("Ammonia", _ammoniaController, Icons.warning_amber_rounded, suffix: "ppm", hint: "e.g. 0.1", required: false, target: "< 0.1 ppm"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveWaterTest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: Colors.teal.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Save Record",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, IconData icon, {String? suffix, String? hint, bool required = true, String? target}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
            if (target != null)
              Text(
                "Ideal: $target",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
              )
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
            suffixText: suffix,
            suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade500, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: required ? (value) {
            if (value == null || value.isEmpty) return 'Required';
            if (double.tryParse(value) == null) return 'Invalid number';
            return null;
          } : (value) {
            if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
              return 'Invalid number';
            }
            return null;
          },
        ),
      ],
    );
  }
}