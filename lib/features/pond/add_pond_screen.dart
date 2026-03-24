import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../farm/farm_provider.dart';

class AddPondScreen extends ConsumerStatefulWidget {
  const AddPondScreen({super.key});

  @override
  ConsumerState<AddPondScreen> createState() => _AddPondScreenState();
}

class _AddPondScreenState extends ConsumerState<AddPondScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _seedCountController = TextEditingController();
  final _plSizeController = TextEditingController();
  
  DateTime _stockingDate = DateTime.now();

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _seedCountController.dispose();
    _plSizeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _stockingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _stockingDate) {
      setState(() {
        _stockingDate = picked;
      });
    }
  }

  void _savePond() {
    if (_formKey.currentState?.validate() ?? false) {
      final farmState = ref.read(farmProvider);
      final currentFarm = farmState.currentFarm;

      if (currentFarm == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("No Farm Selected"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.red.shade600,
          ),
        );
        return;
      }

      final area = double.tryParse(_areaController.text) ?? 0.0;
      final seedCount = int.tryParse(_seedCountController.text) ?? 100000;
      final plSize = int.tryParse(_plSizeController.text) ?? 10;

      // Add Pond to Farm
      ref.read(farmProvider.notifier).addPond(
            currentFarm.id,
            _nameController.text.trim(),
            area,
            seedCount: seedCount,
            plSize: plSize,
            stockingDate: _stockingDate,
          );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Pond Added Successfully"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.green.shade600,
        ),
      );
      
      Navigator.pop(context);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
      validator: required ? (v) => v!.isEmpty ? "Required" : null : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Add New Pond", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Pond Information",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Set up the details for your new pond.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: "Pond Name",
                      hint: "e.g. Pond 5",
                      icon: Icons.water_rounded,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _areaController,
                      label: "Area (Acres)",
                      hint: "e.g. 2.5",
                      icon: Icons.landscape_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _seedCountController,
                      label: "Seed Count",
                      hint: "e.g. 100000",
                      icon: Icons.numbers_rounded,
                      keyboardType: TextInputType.number,
                      required: false,
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Stocking Date", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(_stockingDate),
                                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _savePond,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Create Pond",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}