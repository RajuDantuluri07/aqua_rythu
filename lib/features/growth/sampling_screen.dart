import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../farm/farm_provider.dart';
import 'growth_provider.dart';

class SamplingScreen extends ConsumerStatefulWidget {
  final String pondId;

  const SamplingScreen({super.key, required this.pondId});

  @override
  ConsumerState<SamplingScreen> createState() => _SamplingScreenState();
}

class _SamplingScreenState extends ConsumerState<SamplingScreen> {
  final _weightController = TextEditingController();
  final _countController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _weightController.addListener(() => setState(() {}));
    _countController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _weightController.dispose();
    _countController.dispose();
    super.dispose();
  }

  double get _currentCountSize {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final count = int.tryParse(_countController.text) ?? 0;
    if (weight <= 0 || count <= 0) return 0;
    return count / weight;
  }

  double get _currentABW {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final count = int.tryParse(_countController.text) ?? 0;
    if (weight <= 0 || count <= 0) return 0;
    return (weight * 1000) / count;
  }

  bool get _isValid {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final count = int.tryParse(_countController.text) ?? 0;
    return weight > 0 && count > 0 && weight <= 50 && count <= 500;
  }

  Future<void> _save() async {
    if (!_isValid) return;

    setState(() => _isLoading = true);

    final weight = double.parse(_weightController.text);
    final count = int.parse(_countController.text);
    final doc = ref.read(docProvider(widget.pondId));

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    ref.read(growthProvider(widget.pondId).notifier).addSample(
          weightKg: weight,
          count: count,
          doc: doc,
        );

    setState(() => _isLoading = false);
    
    _weightController.clear();
    _countController.clear();
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Growth sample logged successfully!"),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(docProvider(widget.pondId));
    final growthState = ref.watch(growthProvider(widget.pondId));
    final lastSample = growthState.lastSample;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Growth Sampling", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔵 A. HEADER CARD
            _buildHeaderCard(doc, lastSample),
            const SizedBox(height: 24),

            /// 🟢 B. LOG NEW SAMPLE
            const Text("Log New Sample", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInputCard(),
            const SizedBox(height: 24),

            /// 📜 HISTORY SECTION
            const Text("Sampling History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildHistoryList(growthState.logs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(int doc, GrowthSample? lastSample) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem("Current DOC", "$doc Days", Icons.calendar_today_rounded),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _summaryItem(
              "Last Sampling", 
              lastSample != null ? "${lastSample.countSize.round()} Count" : "No data", 
              Icons.analytics_rounded
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildInputCard() {
    final count = int.tryParse(_countController.text) ?? 0;
    final countSize = _currentCountSize;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField("Sample Weight", _weightController, "kg", "e.g. 2.0", Icons.scale_rounded),
          const SizedBox(height: 20),
          _buildField("Shrimp Count", _countController, "pc", "e.g. 100", Icons.numbers_rounded, isInt: true),
          
          if (count > 0 && count < 20)
            _buildWarning("Sample size too small for accuracy"),
          
          if (countSize > 0 && (countSize < 10 || countSize > 200))
            _buildWarning("Check input values: unusual count size"),

          if (_currentCountSize > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(),
            ),
            _buildPreviewRow(),
          ],

          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isValid && !_isLoading ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : const Text("SAVE SAMPLING DATA", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String suffix, String hint, IconData icon, {bool isInt = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: isInt ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.indigo.shade400, size: 20),
            suffixText: suffix,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildWarning(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade200)),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildPreviewRow() {
    return Row(
      children: [
        Expanded(
          child: _previewItem("Count Size", "${_currentCountSize.round()}", "Count", Colors.green),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _previewItem("Avg Weight", _currentABW.toStringAsFixed(1), "g", Colors.blue),
        ),
      ],
    );
  }

  Widget _previewItem(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<GrowthSample> logs) {
    if (logs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("No samples yet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text("Start tracking your shrimp growth", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final sample = logs[index];
        final prevSample = (index + 1 < logs.length) ? logs[index + 1] : null;
        
        // Calculate growth from last
        final growth = prevSample != null ? (prevSample.countSize - sample.countSize) : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: _leadIcon(sample.countSize),
            title: Row(
              children: [
                Text("${sample.countSize.round()} Count", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                if (growth != 0) ...[
                  const SizedBox(width: 8),
                  _growthBadge(growth),
                ]
              ],
            ),
            subtitle: Text("Avg: ${sample.abw.toStringAsFixed(1)}g • ${DateFormat('d MMM').format(sample.date)}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("DOC ${sample.doc}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Text("Cycle Day", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _leadIcon(double count) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
      child: Icon(Icons.trending_down_rounded, color: Colors.green.shade600, size: 24),
    );
  }

  Widget _growthBadge(double growth) {
    final isPositive = growth > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        "${isPositive ? '+' : ''}${growth.round()} count",
        style: TextStyle(color: isPositive ? Colors.green.shade700 : Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}