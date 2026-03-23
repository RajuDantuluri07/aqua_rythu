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
        const SnackBar(content: Text("Water Log Saved")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safe access to DOC using the existing farm provider logic
    final doc = ref.watch(docProvider(widget.pondId));

    return Scaffold(
      appBar: AppBar(title: const Text("Add Water Test")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("DOC: $doc", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              
              _buildInput("pH Level", _phController),
              _buildInput("Dissolved Oxygen (ppm)", _doController),
              _buildInput("Temperature (°C)", _tempController),
              _buildInput("Salinity (ppt)", _salinityController),
              _buildInput("Alkalinity (ppm)", _alkalinityController),
              _buildInput("Ammonia (ppm)", _ammoniaController),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveWaterTest, // Fix: Pass function reference, don't call it ()
                child: const Text("Save Record"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Required';
          if (double.tryParse(value) == null) return 'Invalid number';
          return null;
        },
      ),
    );
  }
}