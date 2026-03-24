import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void dispose() {
    _weightController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _save() {
    final weight = double.tryParse(_weightController.text);
    final count = int.tryParse(_countController.text);

    if (weight == null || count == null || weight <= 0 || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text("Please enter valid positive numbers"),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.red.shade600,
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final doc = ref.read(docProvider(widget.pondId));

    ref.read(growthProvider(widget.pondId).notifier).updateStats(
          avgWeight: weight,
          totalCount: count,
          doc: doc,
        );

    _weightController.clear();
    _countController.clear();
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text("Sampling data saved successfully", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.teal.shade700,
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(docProvider(widget.pondId));
    final growthState = ref.watch(growthProvider(widget.pondId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Growth Sampling", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 56, 
                bottom: 40, 
                left: 24, 
                right: 24
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.lightBlue.shade600, Colors.indigo.shade600],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text("Current DOC", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "$doc Days", 
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: Colors.white)
                          ),
                        ],
                      ),
                      Container(height: 50, width: 2, color: Colors.white.withOpacity(0.3)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text("Last ABW", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${growthState.avgWeight} g", 
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: Colors.white)
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 16),
                    child: Text(
                      "Log New Sample",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87),
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
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        _buildInputField(
                          controller: _weightController,
                          label: "Avg Body Weight (ABW)",
                          hint: "e.g. 15.5",
                          suffix: "g",
                          icon: Icons.scale_rounded,
                        ),
                        const SizedBox(height: 24),
                        _buildInputField(
                          controller: _countController,
                          label: "Estimated Survival Count",
                          hint: "e.g. 95000",
                          suffix: "PL",
                          icon: Icons.numbers_rounded,
                          isInteger: true,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade600,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: Colors.indigo.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Update Growth Stats",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 16),
                    child: Text(
                      "History",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (growthState.logs.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.history_rounded, size: 56, color: Colors.indigo.shade200),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "No sampling history yet",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Log samples to track shrimp growth",
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final log = growthState.logs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.analytics_rounded, color: Colors.indigo.shade400, size: 28),
                        ),
                        title: Text(
                          "DOC ${log.doc}",
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "${log.date.day}/${log.date.month}/${log.date.year}",
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${log.avgWeight} g",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${log.count} PL",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: growthState.logs.length,
                ),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String suffix,
    required IconData icon,
    bool isInteger = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.indigo.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: isInteger ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade300, fontWeight: FontWeight.w500),
            suffixText: suffix,
            suffixStyle: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black54),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.indigo.shade400, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }
}