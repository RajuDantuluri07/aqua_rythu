import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import '../profile/farm_settings_provider.dart';
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
  final TextEditingController _salinityController = TextEditingController();
  final TextEditingController _alkalinityController = TextEditingController();
  final TextEditingController _nitriteController = TextEditingController();

  // Validation ranges
  static const Map<String, Map<String, dynamic>> _ranges = {
    'ph': {
      'min': 0.0,
      'max': 14.0,
      'optimalMin': 7.5,
      'optimalMax': 8.5,
      'unit': '',
      'name': 'pH'
    },
    'do': {
      'min': 0.0,
      'max': 25.0,
      'optimalMin': 4.0,
      'optimalMax': 8.0,
      'unit': 'ppm',
      'name': 'DO'
    },
    'salinity': {
      'min': 0.0,
      'max': 100.0,
      'optimalMin': 10.0,
      'optimalMax': 25.0,
      'unit': 'ppt',
      'name': 'Salinity'
    },
    'alkalinity': {
      'min': 0.0,
      'max': 1000.0,
      'optimalMin': 100.0,
      'optimalMax': 200.0,
      'unit': 'ppm',
      'name': 'Alkalinity'
    },
    'ammonia': {
      'min': 0.0,
      'max': 10.0,
      'optimalMin': 0.0,
      'optimalMax': 0.1,
      'unit': 'ppm',
      'name': 'Ammonia'
    },
    'nitrite': {
      'min': 0.0,
      'max': 10.0,
      'optimalMin': 0.0,
      'optimalMax': 0.1,
      'unit': 'ppm',
      'name': 'Nitrite'
    },
  };

  @override
  void dispose() {
    _phController.dispose();
    _doController.dispose();
    _salinityController.dispose();
    _alkalinityController.dispose();
    _ammoniaController.dispose();
    _nitriteController.dispose();
    super.dispose();
  }

  void _saveWaterTest() {
    if (_formKey.currentState?.validate() ?? false) {
      final ph = double.tryParse(_phController.text) ?? 0;
      final doVal = double.tryParse(_doController.text) ?? 0;
      final sal = double.tryParse(_salinityController.text) ?? 0;
      final alk = double.tryParse(_alkalinityController.text) ?? 0;
      final ammonia = double.tryParse(_ammoniaController.text) ?? 0;
      final nitrite = double.tryParse(_nitriteController.text) ?? 0;
      final doc = ref.read(docProvider(widget.pondId));

      ref.read(waterProvider(widget.pondId).notifier).addLog(
            doc: doc,
            ph: ph,
            dissolvedOxygen: doVal,
            salinity: sal,
            alkalinity: alk,
            ammonia: ammonia,
            nitrite: nitrite,
          );

      // Clear inputs after save
      _phController.clear();
      _doController.clear();
      _salinityController.clear();
      _alkalinityController.clear();
      _ammoniaController.clear();
      _nitriteController.clear();

      // Calculate health score for snackbar message
      int score = 100;
      if (doVal < 4) {
        score -= 20;
      } else if (doVal < 5) {
        score -= 10;
      }
      if (ph < 7.5 || ph > 8.5) {
        score -= 10;
      }
      if (sal < 10 || sal > 25) {
        score -= 10;
      }
      if (alk < 100 || alk > 200) {
        score -= 10;
      }
      if (ammonia > 0.3) {
        score -= 20;
      } else if (ammonia > 0.1) {
        score -= 10;
      }
      if (nitrite > 0.3) {
        score -= 20;
      } else if (nitrite > 0.1) {
        score -= 10;
      }

      String snackMsg = "Saved successfully";
      Color snackColor = Colors.teal;
      IconData snackIcon = Icons.check_circle;

      if (score < 60) {
        snackMsg += " ⚠️ Water condition is critical";
        snackColor = Colors.red.shade700;
        snackIcon = Icons.warning_amber_rounded;
      } else if (score < 80) {
        snackMsg += " ⚠️ Water condition is below optimal";
        snackColor = Colors.orange.shade800;
        snackIcon = Icons.warning_amber_rounded;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(snackIcon, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(snackMsg,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: snackColor,
          margin: const EdgeInsets.all(16),
          elevation: 6,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(waterProvider(widget.pondId));
    final farmSettings = ref.watch(farmSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Water Quality Test",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          children: [
            // Latest Test Results Summary Card
            if (logs.isNotEmpty)
              Builder(builder: (context) {
                final latest = logs.first;
                final statusColor = latest.healthColor(farmSettings);
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppRadius.rBase,
                    boxShadow: [
                      BoxShadow(
                          color: statusColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("LATEST TEST STATUS",
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.5)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              "${latest.getHealthScore(farmSettings)}/100",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        latest.healthStatus(farmSettings).toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "DOC ${latest.doc} • ${DateFormat('dd MMM, hh:mm a').format(latest.date)}",
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      if (latest.recommendations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("RECOMMENDATIONS:",
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10)),
                        ),
                        const SizedBox(height: 6),
                        ...latest.recommendations.map((warning) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      color: Colors.white70, size: 14),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      warning,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                );
              }),

            const SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _buildInput(
                        label: "pH Level",
                        controller: _phController,
                        icon: Icons.opacity_rounded,
                        hint: "7.5",
                        paramKey: 'ph',
                      )),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildInput(
                        label: "Dissolved Oxygen",
                        controller: _doController,
                        icon: Icons.water,
                        hint: "5.0",
                        suffix: "ppm",
                        paramKey: 'do',
                      )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                          child: _buildInput(
                        label: "Salinity",
                        controller: _salinityController,
                        icon: Icons.blur_on_rounded,
                        hint: "15",
                        suffix: "ppt",
                        paramKey: 'salinity',
                      )),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildInput(
                        label: "Alkalinity",
                        controller: _alkalinityController,
                        icon: Icons.science_outlined,
                        hint: "120",
                        suffix: "ppm",
                        paramKey: 'alkalinity',
                      )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                          child: _buildInput(
                        label: "Ammonia",
                        controller: _ammoniaController,
                        icon: Icons.warning_amber_rounded,
                        hint: "0.1",
                        suffix: "ppm",
                        paramKey: 'ammonia',
                      )),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildInput(
                        label: "Nitrite",
                        controller: _nitriteController,
                        icon: Icons.warning_rounded,
                        hint: "0.1",
                        suffix: "ppm",
                        paramKey: 'nitrite',
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
                        shape:
                            RoundedRectangleBorder(borderRadius: AppRadius.rs),
                      ),
                      child: const Text("SAVE WATER LOG",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Recent Logs",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.rs,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fullHeaderRow(),
                          ...logs.take(10).map((log) => _fullLogRow(log, farmSettings)),
                        ],
                      ),
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

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    String? suffix,
    required String paramKey,
  }) {
    final range = _ranges[paramKey]!;
    final currentValue = double.tryParse(controller.text);
    final isOptimal = currentValue != null &&
        currentValue >= range['optimalMin'] &&
        currentValue <= range['optimalMax'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textSecondary)),
            if (currentValue != null) ...[
              const SizedBox(width: 6),
              Text(
                isOptimal ? "✅" : "⚠️",
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            prefixIcon: Icon(icon, size: 20, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: AppRadius.rs,
              borderSide: BorderSide(
                color: currentValue != null && !isOptimal
                    ? Colors.orange
                    : AppColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.rs,
              borderSide: BorderSide(
                color: currentValue != null && !isOptimal
                    ? Colors.orange
                    : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.rs,
              borderSide: BorderSide(color: Colors.teal.shade500, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Required';
            final double? numValue = double.tryParse(value);
            if (numValue == null) return 'Invalid number';
            if (numValue < range['min'] || numValue > range['max']) {
              return '${range['name']} should be ${range['min']}-${range['max']}${range['unit']}';
            }
            return null;
          },
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 2),
        Text(
          "Optimal: ${range['optimalMin']}-${range['optimalMax']}${range['unit']}",
          style: const TextStyle(fontSize: 9, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _fullHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
        color: Color(0xFFF8FAFC),
      ),
      child: const Row(
        children: [
          SizedBox(
              width: 60,
              child: Text("DATE",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
          SizedBox(
              width: 40,
              child: Text("DOC",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
          SizedBox(
              width: 45,
              child: Text("pH",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
          SizedBox(
              width: 45,
              child: Text("DO",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
          SizedBox(
              width: 50,
              child: Text("Sal",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
          SizedBox(
              width: 55,
              child: Text("Alk",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
          SizedBox(
              width: 55,
              child: Text("NH3",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
          SizedBox(
              width: 55,
              child: Text("NO2",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
          SizedBox(
              width: 55,
              child: Text("Score",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
        ],
      ),
    );
  }

  Widget _fullLogRow(WaterLog log, FarmSettings farmSettings) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 60,
              child: Text(DateFormat("dd MMM").format(log.date),
                  style: const TextStyle(fontSize: 11))),
          SizedBox(
              width: 40,
              child: Text("${log.doc}",
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500))),
          SizedBox(
              width: 45,
              child: Text(log.ph.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getParameterColor(log.ph, 'ph')))),
          SizedBox(
              width: 45,
              child: Text(log.dissolvedOxygen.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getParameterColor(log.dissolvedOxygen, 'do')))),
          SizedBox(
              width: 50,
              child: Text(log.salinity.toStringAsFixed(0),
                  style: TextStyle(
                      fontSize: 11,
                      color: _getParameterColor(log.salinity, 'salinity')))),
          SizedBox(
              width: 55,
              child: Text(log.alkalinity.toStringAsFixed(0),
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          _getParameterColor(log.alkalinity, 'alkalinity')))),
          SizedBox(
              width: 55,
              child: Text(log.ammonia.toStringAsFixed(2),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _getParameterColor(log.ammonia, 'ammonia')))),
          SizedBox(
              width: 55,
              child: Text(log.nitrite.toStringAsFixed(2),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _getParameterColor(log.nitrite, 'nitrite')))),
          SizedBox(
            width: 55,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: log.healthColor(farmSettings).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${log.getHealthScore(farmSettings)}",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: log.healthColor(farmSettings)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getParameterColor(double value, String param) {
    final range = _ranges[param]!;
    if (value < range['optimalMin'] || value > range['optimalMax']) {
      return Colors.orange.shade700;
    }
    return Colors.green.shade700;
  }
}
