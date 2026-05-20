import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../farm/farm_provider.dart';
import 'package:aqua_rythu/core/services/pond_service.dart';
import '../../routes/app_routes.dart';

class SmartFeedInitializationScreen extends ConsumerStatefulWidget {
  final String pondId;
  final String farmId;
  final int doc;
  // PRO: calls initializeSmartFeedPond + generates today's rounds.
  // FREE: skips smart init entirely, only generates today's operational rounds.
  final bool isPro;

  const SmartFeedInitializationScreen({
    super.key,
    required this.pondId,
    required this.farmId,
    required this.doc,
    this.isPro = true,
  });

  @override
  ConsumerState<SmartFeedInitializationScreen> createState() =>
      _SmartFeedInitializationScreenState();
}

class _SmartFeedInitializationScreenState
    extends ConsumerState<SmartFeedInitializationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedKgController = TextEditingController();
  final _abwController = TextEditingController();
  final _survivalController = TextEditingController();
  final _roundsController = TextEditingController();
  DateTime? _lastSamplingDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _feedKgController.dispose();
    _abwController.dispose();
    _survivalController.dispose();
    _roundsController.dispose();
    super.dispose();
  }

  Future<void> _selectSamplingDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastSamplingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _lastSamplingDate = picked);
    }
  }

  String? _validatePositiveDecimal(String? value, String fieldName) {
    if (value == null || value.isEmpty) return '$fieldName is required';
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return 'Enter a valid number';
    if (parsed <= 0) return '$fieldName must be greater than 0';
    return null;
  }

  String? _validateSurvival(String? value) {
    if (value == null || value.isEmpty) return null; // optional
    final parsed = double.tryParse(value);
    if (parsed == null) return 'Enter a valid number';
    if (parsed <= 0 || parsed > 100) return 'Enter a value between 1 and 100';
    return null;
  }

  String? _validateRounds(String? value) {
    if (value == null || value.isEmpty) return 'Feed rounds is required';
    final parsed = int.tryParse(value);
    if (parsed == null) return 'Enter a whole number';
    if (parsed < 1 || parsed > 12) return 'Enter a value between 1 and 12';
    return null;
  }

  Future<void> _activate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final feedKg =
          double.parse(_feedKgController.text.replaceAll(',', '.'));
      final abw = _abwController.text.trim().isEmpty
          ? null
          : double.parse(_abwController.text.replaceAll(',', '.'));
      final survivalPct = _survivalController.text.trim().isEmpty
          ? null
          : double.parse(_survivalController.text);
      final roundsPerDay = int.parse(_roundsController.text);

      final pondService = PondService();
      if (widget.isPro) {
        await pondService.initializeSmartFeedPond(
          pondId: widget.pondId,
          doc: widget.doc,
          currentFeedKg: feedKg,
          abw: abw,
          survivalPct: survivalPct,
          roundsPerDay: roundsPerDay,
          lastSamplingDate: _lastSamplingDate,
        );
      }
      await pondService.generateTodayOperationalRounds(
        pondId: widget.pondId,
        doc: widget.doc,
        totalFeedKg: feedKg,
        roundsPerDay: roundsPerDay,
      );

      await ref
          .read(farmProvider.notifier)
          .loadFarms(setAsSelectedId: widget.farmId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              widget.isPro ? 'Smart feed activated successfully' : 'Pond set up successfully'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.green.shade600,
        ),
      );

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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = const TextInputType.numberWithOptions(decimal: true),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          widget.isPro ? 'Initialize Pond Intelligence' : 'Set Up Active Pond',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DOC context banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primary.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade800),
                          children: [
                            const TextSpan(text: 'Your pond is on '),
                            TextSpan(
                              text: 'DOC ${widget.doc}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: primary),
                            ),
                            TextSpan(
                              text: widget.isPro
                                  ? '. Provide current data to activate smart feeding immediately.'
                                  : '. Enter your current feed amount to start tracking.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Mandatory fields card
              const Text(
                'Required Information',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _feedKgController,
                      label: 'Current Feed / Day (kg)',
                      hint: 'e.g. 45.5',
                      icon: Icons.set_meal_rounded,
                      validator: (v) =>
                          _validatePositiveDecimal(v, 'Current feed'),
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      controller: _abwController,
                      label: 'Current ABW (g) — optional',
                      hint: 'e.g. 8.5',
                      icon: Icons.monitor_weight_outlined,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final parsed = double.tryParse(v.replaceAll(',', '.'));
                        if (parsed == null) return 'Enter a valid number';
                        if (parsed <= 0) return 'ABW must be greater than 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      controller: _survivalController,
                      label: 'Survival (%) — optional',
                      hint: 'e.g. 80',
                      icon: Icons.trending_up_rounded,
                      validator: _validateSurvival,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      controller: _roundsController,
                      label: 'Feed Rounds / Day',
                      hint: 'e.g. 4',
                      icon: Icons.repeat_rounded,
                      validator: _validateRounds,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Optional fields card
              const Text(
                'Optional',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: InkWell(
                  onTap: () => _selectSamplingDate(context),
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
                        Icon(Icons.calendar_today_rounded, color: primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Last Sampling Date',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _lastSamplingDate != null
                                    ? DateFormat('dd MMM yyyy')
                                        .format(_lastSamplingDate!)
                                    : 'Not set',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _lastSamplingDate != null
                                      ? Colors.black87
                                      : Colors.grey.shade400,
                                ),
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
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _activate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: primary.withOpacity(0.4),
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
                      : Text(
                          widget.isPro ? 'Activate Smart Feed' : 'Start Tracking Pond',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
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
