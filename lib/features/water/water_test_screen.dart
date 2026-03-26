import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'water_provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';

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

  String? _validateRange(double? val, double min, double max, String name, [String unit = ""]) {
    if (val == null) return 'Enter $name';
    final unitStr = unit.isNotEmpty ? " $unit" : "";
    if (val < min || val > max) return '$name should be $min-$max$unitStr';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(docProvider(widget.pondId));
    final logs = ref.watch(waterProvider(widget.pondId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Water Quality Test", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          children: [
            // KPI Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade700, Colors.teal.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppRadius.rBase,
                boxShadow: [
                  BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("CURRENT STATUS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                        child: const Text("OPTIMAL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "POND 1 • DOC $doc",
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: logs.take(3).map((log) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Chip(
                        label: Text("pH ${log.ph}"),
                        backgroundColor: Colors.white24,
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildInput(label: "pH Level", controller: _phController, icon: Icons.opacity_rounded, hint: "7.5",
                        validator: (val) {
                          return _validateRange(val, 6.0, 9.5, "pH");
                        },
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInput(label: "Dissolved Oxygen", controller: _doController, icon: Icons.water, hint: "5.0", suffix: "ppm",
                        validator: (val) {
                          return _validateRange(val, 2.0, 20.0, "DO", "ppm");
                        },
                      )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildInput(label: "Temperature", controller: _tempController, icon: Icons.thermostat_rounded, hint: "28", suffix: "°C",
                        validator: (val) {
                          return _validateRange(val, 15.0, 40.0, "Temp", "°C");
                        },
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInput(label: "Salinity", controller: _salinityController, icon: Icons.blur_on_rounded, hint: "15", suffix: "ppt",
                        validator: (val) {
                          return _validateRange(val, 0.0, 45.0, "Salinity", "ppt");
                        },
                      )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildInput(label: "Alkalinity", controller: _alkalinityController, icon: Icons.science_outlined, hint: "120", suffix: "ppm",
                        validator: (val) {
                          return _validateRange(val, 50.0, 250.0, "Alkalinity", "ppm");
                        },
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInput(label: "Ammonia", controller: _ammoniaController, icon: Icons.warning_amber_rounded, hint: "0.1", suffix: "ppm",
                        validator: (val) {
                          return _validateRange(val, 0.0, 2.0, "Ammonia", "ppm");
                        },
                      )),
                    ],
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveWaterTest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.rs),
                      ),
                      child: const Text("SAVE WATER LOG", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Recent Logs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.rs,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _headerRow(),
                        ...logs.take(5).map((log) => _logRow(log)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({required TextEditingController controller, required String label, required IconData icon, required String hint, String? suffix, String? Function(double?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextFormField( // Changed from TextField to TextFormField
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            prefixIcon: Icon(icon, size: 20, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: AppRadius.rs, borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: AppRadius.rs, borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: AppRadius.rs, borderSide: BorderSide(color: Colors.teal.shade500, width: 2)), // Added focused border for consistency
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            final double? numValue = double.tryParse(value);
            if (numValue == null) {
              return 'Invalid number';
            }
            return validator?.call(numValue); // Call the custom validator
          },
        ),
      ],
    );
  }

  Widget _headerRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
        color: Color(0xFFF8FAFC),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text("DATE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary))),
          Expanded(flex: 1, child: Text("DOC", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary))),
          Expanded(flex: 2, child: Text("pH", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary))),
          Expanded(flex: 2, child: Text("DO", textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary))),
        ],
      ),
    );
  }

  Widget _logRow(dynamic log) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(DateFormat("dd MMM").format(log.date), style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(flex: 1, child: Text("${log.doc}", style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(flex: 2, child: Text("${log.ph}", style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text("${log.dissolvedOxygen}", textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}