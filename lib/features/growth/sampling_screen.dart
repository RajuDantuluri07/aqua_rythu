import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'growth_provider.dart';
import 'sampling_log.dart';
import '../farm/farm_provider.dart';
import '../upgrade/access_control_hooks.dart';
import '../../core/theme/app_theme.dart';
import 'package:aqua_rythu/core/services/sampling_service.dart';
import '../../core/utils/logger.dart';

class SamplingScreen extends ConsumerStatefulWidget {
  final String pondId;
  const SamplingScreen({super.key, required this.pondId});

  @override
  ConsumerState<SamplingScreen> createState() => _SamplingScreenState();
}

class _SamplingScreenState extends ConsumerState<SamplingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _weightKgCtrl = TextEditingController();
  final _countGroupsCtrl = TextEditingController();

  // State
  int _piecesPerGroup = 2;

  // Computed values
  double get _weightKg => double.tryParse(_weightKgCtrl.text) ?? 0;
  int get _countGroups => int.tryParse(_countGroupsCtrl.text) ?? 0;
  int get _totalPieces => _countGroups * _piecesPerGroup;

  double get _avgWeight {
    if (_totalPieces == 0 || _weightKg == 0) return 0;
    return (_weightKg * 1000) / _totalPieces;
  }

  double get _countPerKg {
    if (_avgWeight == 0) return 0;
    return 1000 / _avgWeight;
  }

  double _calculateBiomass(int seedCount, double survival) {
    if (_avgWeight == 0) return 0;
    return (seedCount * survival * _avgWeight) / 1000;
  }

  String? _warningMessage;
  bool get _isValid => _weightKg > 0 && _countGroups > 0 && _totalPieces > 0;

  // Recalculate when inputs change
  void _recalculate() {
    setState(() {
      if (_weightKg > 0 && _countGroups > 0) {
        if (_totalPieces < 50) {
          _warningMessage = "Low sample size. Try at least 50 prawns.";
        } else {
          _warningMessage = null;
        }
      } else {
        _warningMessage = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _weightKgCtrl.addListener(() => _recalculate());
    _countGroupsCtrl.addListener(() => _recalculate());
  }

  @override
  void dispose() {
    _weightKgCtrl.dispose();
    _countGroupsCtrl.dispose();
    super.dispose();
  }

  String _daysSince(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days == 0) return "today";
    if (days == 1) return "1 day ago";
    return "$days days ago";
  }

  String? _validateWeight(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final val = double.tryParse(value);
    if (val == null) return 'Invalid number';
    if (val <= 0) return 'Weight must be > 0';
    if (val > 100) return 'Weight seems too high (max 100 kg)';
    return null;
  }

  String? _validateGroups(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final val = int.tryParse(value);
    if (val == null) return 'Invalid number';
    if (val <= 0) return 'Count must be > 0';
    if (val > 500) return 'Count seems too high (max 500)';
    return null;
  }

  void _saveSampling(int doc) {
    if (_formKey.currentState?.validate() ?? false) {
      final abw = _avgWeight;
      final pondId = widget.pondId;

      // Update in-memory growth log immediately
      ref.read(growthProvider(pondId).notifier).addLog(
            SamplingLog(
              doc: doc,
              abw: abw,
              date: DateTime.now(),
            ),
          );

      // Persist sampling + update pond ABW (fire-and-forget)
      SamplingService().addSampling(
        pondId: pondId,
        date: DateTime.now(),
        doc: doc,
        weightKg: _weightKg,
        totalPieces: _totalPieces,
        averageBodyWeight: abw,
      ).catchError((e) {
        AppLogger.error('Sampling save failed for pond $pondId', e);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sample saved — will gently adjust feed accuracy"),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  String _getGrowthInsight(
      List<SamplingLog> logs, int currentDoc, double currentAbw) {
    if (logs.isEmpty || logs.first.doc == currentDoc) {
      return "Enter sample to see growth insights";
    }

    final prevLog = logs.first;
    final daysDiff = currentDoc - prevLog.doc;
    if (daysDiff <= 0) return "Insufficient data";

    final growthPerDay = (currentAbw - prevLog.averageBodyWeight) / daysDiff;

    if (growthPerDay >= 0.25) {
      return "Growth is on track ✅";
    } else if (growthPerDay >= 0.15) {
      return "Growth slightly below expected ⚠️";
    } else {
      return "Growth is slow — check feed & water ⚠️";
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(growthProvider(widget.pondId));
    final doc = ref.watch(docProvider(widget.pondId));
    final farmState = ref.watch(farmProvider);

    // Find pond for seed count
    Pond? pond;
    for (var f in farmState.farms) {
      for (var p in f.ponds) {
        if (p.id == widget.pondId) {
          pond = p;
          break;
        }
      }
    }
    final seedCount = pond?.seedCount ?? 100000;

    // Simple survival model
    double survival = 1.0;
    if (doc > 30) survival = 0.95;
    if (doc > 60) survival = 0.90;

    final currentAbw = logs.isNotEmpty ? logs.first.averageBodyWeight : 0.0;
    const targetAbw = 5.0; // Target ABW at this DOC (can be improved)

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Growth Sampling",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ABW Card - Show current if exists
              if (logs
                  .isNotEmpty) // Show ABW card only if there's existing data
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppRadius.rBase,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("CURRENT ABW",
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                              Text(
                                logs.isNotEmpty
                                    ? "Last updated: ${_daysSince(logs.first.date)}"
                                    : "",
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Text("TARGET ${targetAbw}g",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentAbw > 0
                            ? "${currentAbw.toStringAsFixed(2)} g"
                            : "-- g",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: logs
                            .take(3)
                            .map((log) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Chip(
                                    label: Text(
                                        "${log.averageBodyWeight.toStringAsFixed(1)}g"),
                                    backgroundColor: Colors.white24,
                                    labelStyle: const TextStyle(
                                        color: Colors.white, fontSize: 11),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide.none,
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Weight Input
              _buildWeightInput(),

              const SizedBox(height: 20),

              // Count Section (Shows only after weight entered)
              if (_weightKg > 0) ...[
                _buildCountSection(),
                const SizedBox(height: 20),
                _buildPiecesPerGroupChip(),
                const SizedBox(height: 12),
                _buildHelperText(),
              ],

              // Warning Message
              if (_warningMessage != null) ...[
                const SizedBox(height: 12),
                _buildWarningBox(_warningMessage!),
              ],

              // Results Section (Shows only when valid)
              if (_isValid) ...[
                const SizedBox(height: 24),
                _buildResultsSection(_calculateBiomass(seedCount, survival)),
                const SizedBox(height: 12),
                // Growth insight is a PRO feature — FREE users see a locked
                // overlay that taps through to upgrade.
                ProFeatureWrapper(
                  featureId: FeatureIds.growthIntelligence,
                  child: _buildGrowthInsightWidget(logs, doc, _avgWeight),
                ),
              ],

              const SizedBox(height: 24),

              // Optional hint
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppColors.textTertiary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Optional: Update shrimp weight for better accuracy",
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isValid ? () => _saveSampling(doc) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.rs),
                  ),
                  child: const Text("UPDATE SAMPLE (OPTIONAL)",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 32),

              // History Ledger
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Recent Logs",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    _historyHeaderRow(),
                    ...logs.take(5).map((log) => _historyLogRow(log)),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeightInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Total Sample Weight",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _weightKgCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: "Weight (kg)",
            hintText: "e.g. 1.3",
            prefixIcon: const Icon(Icons.monitor_weight_outlined,
                size: 20, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: AppRadius.rs,
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.rs,
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.rs,
                borderSide: BorderSide(
                    color: Theme.of(context).primaryColor, width: 2)),
          ),
          validator: _validateWeight,
        ),
      ],
    );
  }

  Widget _buildCountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Number of Counts",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _countGroupsCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: "e.g. 50",
            prefixIcon:
                const Icon(Icons.numbers_rounded, size: 20, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: AppRadius.rs,
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.rs,
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.rs,
                borderSide: BorderSide(
                    color: Theme.of(context).primaryColor, width: 2)),
          ),
          validator: _validateGroups,
        ),
      ],
    );
  }

  Widget _buildPiecesPerGroupChip() {
    const options = [1, 2, 3, 5];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Prawns per Count",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((value) {
            return ChoiceChip(
              label: Text("$value"),
              selected: _piecesPerGroup == value,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _piecesPerGroup = value;
                    _recalculate();
                  });
                }
              },
              selectedColor: AppColors.primary,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: _piecesPerGroup == value
                    ? Colors.white
                    : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHelperText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: AppColors.textTertiary),
          SizedBox(width: 6),
          Text(
            "Count prawns (you can count 2 or more at once)",
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(double biomass) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: AppRadius.rs,
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _resultStat("AVG WEIGHT", "${_avgWeight.toStringAsFixed(2)} g"),
              _resultStat("COUNT/KG", "${_countPerKg.toInt()}"),
              _resultStat("BIOMASS", "${biomass.toInt()} kg"),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Total pieces: $_totalPieces",
            style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _resultStat(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.green.shade800)),
      ],
    );
  }

  Widget _buildGrowthInsightWidget(
      List<SamplingLog> logs, int doc, double currentAbw) {
    final insight = _getGrowthInsight(logs, doc, currentAbw);
    Color color;
    IconData icon;

    if (insight.contains("✅")) {
      color = Colors.green.shade700;
      icon = Icons.check_circle_outline;
    } else if (insight.contains("⚠️")) {
      color = Colors.orange.shade700;
      icon = Icons.warning_amber_rounded;
    } else {
      color = Colors.blue.shade700;
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insight,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
        color: Color(0xFFF8FAFC),
      ),
      child: const Row(
        children: [
          Expanded(
              flex: 2,
              child: Text("DATE",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
          Expanded(
              flex: 1,
              child: Text("DOC",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
          Expanded(
              flex: 2,
              child: Text("AVG.WT",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
          Expanded(
              flex: 2,
              child: Text("PIECES",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary))),
        ],
      ),
    );
  }

  Widget _historyLogRow(SamplingLog log) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(DateFormat("dd MMM").format(log.date),
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
              flex: 1,
              child: Text("${log.doc}",
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
              flex: 2,
              child: Text("${log.averageBodyWeight.toStringAsFixed(2)}g",
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 2,
              child: Text("${log.totalPieces}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}
