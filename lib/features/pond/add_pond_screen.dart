import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../farm/farm_provider.dart';
import '../../services/pond_service.dart';
import '../../routes/app_routes.dart';

class AddPondScreen extends ConsumerStatefulWidget {
  final String? farmId;
  const AddPondScreen({super.key, this.farmId});

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
  int _numTrays = 4;
  bool _isLoading = false;

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

  String? _validateArea(String? value) {
    if (value == null || value.isEmpty) {
      return "Area is required";
    }
    final area = double.tryParse(value);
    if (area == null) {
      return "Enter a valid number";
    }
    if (area <= 0) {
      return "Area must be greater than 0";
    }
    if (area > 100) {
      return "Area seems too large. Max: 100 acres";
    }
    return null;
  }

  String? _validateSeedCount(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    final count = int.tryParse(value);
    if (count == null) {
      return "Enter a valid whole number";
    }
    if (count <= 0) {
      return "Seed count must be greater than 0";
    }
    if (count > 10000000) {
      return "Seed count seems too large (max: 10M)";
    }
    return null;
  }

  String? _validatePlSize(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    final size = int.tryParse(value);
    if (size == null) {
      return "Enter a valid whole number";
    }
    if (size <= 0) {
      return "PL size must be greater than 0";
    }
    if (size > 50) {
      return "PL size seems too large (typical: 5-30mm)";
    }
    return null;
  }

  Future<void> _savePond() async {
    if (_formKey.currentState?.validate() ?? false) {
      final selectedFarmId = widget.farmId ?? ref.read(farmProvider).currentFarm?.id;

      if (selectedFarmId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("No Farm Selected"),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.red.shade600,
          ),
        );
        return;
      }

      // Sanitize input: replace commas with dots for universal parsing
      final sanitizedArea = _areaController.text.replaceAll(',', '.');
      final area = double.tryParse(sanitizedArea) ?? 0.0;
      
      final seedCount = _seedCountController.text.isEmpty 
          ? 100000 
          : int.parse(_seedCountController.text);
      final plSize = _plSizeController.text.isEmpty 
          ? 10 
          : int.parse(_plSizeController.text);

      setState(() => _isLoading = true);
      try {
        final pondService = PondService();

        await pondService.createPond(
          farmId: selectedFarmId,
          name: _nameController.text.trim(),
          area: area,
          stockingDate: _stockingDate,
          seedCount: seedCount,
          plSize: plSize,
          numTrays: _numTrays,
        );

        // Refresh the provider to sync the new pond from Supabase
        await ref.read(farmProvider.notifier).loadFarms(setAsSelectedId: selectedFarmId);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Pond created successfully"),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.green.shade600,
          ),
        );

        // Flag feed schedule tip — shown once on first pond creation
        final prefs = await SharedPreferences.getInstance();
        final alreadyShown = prefs.getBool('feed_schedule_tip_shown') ?? false;
        if (!alreadyShown) {
          await prefs.setBool('feed_schedule_tip_pending', true);
          await prefs.setBool('feed_schedule_tip_shown', true);
        }

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.pondDashboard);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
    String? Function(String?)? validator,
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
          borderSide:
              BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
      validator: validator ?? (required ? (v) => v!.isEmpty ? "Required" : null : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Add New Pond",
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: _validateArea,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _seedCountController,
                      label: "Seed Count",
                      hint: "e.g. 100000",
                      icon: Icons.numbers_rounded,
                      keyboardType: TextInputType.number,
                      required: false,
                      validator: _validateSeedCount,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _plSizeController,
                      label: "PL Size (mm)",
                      hint: "e.g. 10",
                      icon: Icons.straighten_rounded,
                      keyboardType: TextInputType.number,
                      required: false,
                      validator: _validatePlSize,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<int>(
                      value: _numTrays,
                      decoration: InputDecoration(
                        labelText: "Number of Trays",
                        prefixIcon: Icon(Icons.storage_rounded,
                            color: Theme.of(context).primaryColor),
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
                          borderSide: BorderSide(
                              color: Theme.of(context).primaryColor, width: 2),
                        ),
                      ),
                      items: [1, 2, 3, 4, 5, 6]
                          .map((tray) => DropdownMenuItem(
                                value: tray,
                                child: Text("$tray"),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _numTrays = value);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded,
                                color: Theme.of(context).primaryColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Stocking Date",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy')
                                        .format(_stockingDate),
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 16, color: Colors.grey.shade400),
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
                  onPressed: _isLoading ? null : _savePond,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor:
                        Theme.of(context).primaryColor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          "Create Pond",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5),
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
