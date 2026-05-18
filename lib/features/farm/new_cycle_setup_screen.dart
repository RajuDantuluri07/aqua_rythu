import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'farm_provider.dart';
import '../harvest/harvest_provider.dart';
import '../feed/feed_history_provider.dart';
import '../tray/tray_provider.dart';
import '../water/water_provider.dart';
import '../supplements/supplement_provider.dart';
import '../pond/pond_dashboard_provider.dart';
import '../growth/growth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/product_provider.dart';
import 'package:aqua_rythu/core/services/pond_service.dart';
import '../../core/services/crop_cycle_service.dart';
import '../../core/models/crop_cycle.dart';
import '../../core/utils/logger.dart';

class NewCycleSetupScreen extends ConsumerStatefulWidget {
  final String pondId;
  final String farmId;

  const NewCycleSetupScreen({
    super.key,
    required this.pondId,
    required this.farmId,
  });

  @override
  ConsumerState<NewCycleSetupScreen> createState() =>
      _NewCycleSetupScreenState();
}

class _NewCycleSetupScreenState extends ConsumerState<NewCycleSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _seedCtrl = TextEditingController(text: '100000');
  final _plSizeCtrl = TextEditingController(text: '10');
  final _cycleNameCtrl = TextEditingController();

  int _selectedTrays = 4;
  DateTime _stockingDate = DateTime.now();
  String? _selectedFeedBrandId;

  // Crop assignment
  bool _joinExisting = false;
  String? _selectedCycleId;
  List<CropCycle> _activeCycles = [];
  bool _loadingCycles = true;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadActiveCycles();
  }

  @override
  void dispose() {
    _seedCtrl.dispose();
    _plSizeCtrl.dispose();
    _cycleNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActiveCycles() async {
    try {
      final cycles =
          await CropCycleService().getActiveCycles(widget.farmId);
      if (mounted) {
        setState(() {
          _activeCycles = cycles;
          _loadingCycles = false;
          // Auto-suggest joining if there's an active cycle with DOC < 10
          if (cycles.isNotEmpty) {
            final recent = cycles.where((c) {
              if (c.stockingDate == null) return false;
              final doc =
                  DateTime.now().difference(c.stockingDate!).inDays + 1;
              return doc <= 10;
            }).toList();
            if (recent.isNotEmpty) {
              _joinExisting = true;
              _selectedCycleId = recent.first.id;
            }
          }
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load active cycles', e);
      if (mounted) setState(() => _loadingCycles = false);
    }
  }

  Future<void> _startCycle() async {
    if (!_formKey.currentState!.validate()) return;
    if (_joinExisting && _selectedCycleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a crop to join.')),
      );
      return;
    }

    final seedCount = int.tryParse(_seedCtrl.text.trim());
    final plSize = int.tryParse(_plSizeCtrl.text.trim());

    if (seedCount == null || plSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid input. Please check your values.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await PondService().startNewCropCycle(
        farmId: widget.farmId,
        pondId: widget.pondId,
        stockingDate: _stockingDate,
        seedCount: seedCount,
        plSize: plSize,
        numTrays: _selectedTrays,
        feedBrandId: _selectedFeedBrandId,
        existingCycleId: _joinExisting ? _selectedCycleId : null,
        cycleName: !_joinExisting && _cycleNameCtrl.text.trim().isNotEmpty
            ? _cycleNameCtrl.text.trim()
            : null,
      );
    } catch (e) {
      AppLogger.error('New cycle DB reset failed', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start new cycle. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Clear in-memory state
    ref.read(farmProvider.notifier).resetPond(
          widget.pondId,
          seedCount: seedCount,
          plSize: plSize,
          stockingDate: _stockingDate,
          numTrays: _selectedTrays,
        );
    ref.read(harvestProvider(widget.pondId).notifier).clearHarvests();
    ref.read(feedHistoryProvider.notifier).clearHistory(widget.pondId);
    ref.read(trayProvider(widget.pondId).notifier).clearLogs();
    ref.read(waterProvider(widget.pondId).notifier).clearLogs();
    ref.read(growthProvider(widget.pondId).notifier).clearLogs();
    ref.read(supplementProvider.notifier).clearForPond(widget.pondId);
    ref.invalidate(supplementLogProvider(widget.pondId));
    ref
        .read(pondDashboardProvider(widget.pondId).notifier)
        .resetPondState(widget.pondId);

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New crop cycle started successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        title: const Text('Start New Cycle'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Crop Assignment ───────────────────────────────────────
              if (!_loadingCycles && _activeCycles.isNotEmpty) ...[
                _buildCropAssignmentSection(),
                const SizedBox(height: 24),
              ],

              // Info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This will reset the pond to DOC 1 and generate a new blind feed plan.',
                        style: TextStyle(
                            color: Colors.blue.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Stocking Date ─────────────────────────────────────────
              _buildLabel('Stocking Date'),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _stockingDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _stockingDate = picked);
                },
                child: _inputContainer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMM yyyy').format(_stockingDate),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Icon(Icons.calendar_today_rounded,
                          size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              _buildInput('Seed Count', _seedCtrl, Icons.scatter_plot_rounded,
                  isNumber: true),
              const SizedBox(height: 20),
              _buildInput('PL Size', _plSizeCtrl, Icons.straighten_rounded,
                  isNumber: true),

              // Cycle name (only for new crop)
              if (!_joinExisting) ...[
                const SizedBox(height: 20),
                _buildLabel('Crop Name (optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _cycleNameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Summer Batch, May Cycle',
                    prefixIcon: const Icon(Icons.label_outline,
                        color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              _buildLabel('Feed Company'),
              const SizedBox(height: 8),
              _buildFeedBrandDropdown(),

              const SizedBox(height: 20),
              _buildLabel('Number of Trays'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedTrays,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.grid_view_rounded,
                      color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300)),
                ),
                items: [2, 4, 6]
                    .map((e) =>
                        DropdownMenuItem(value: e, child: Text('$e Trays')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTrays = val);
                },
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startCycle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('LAUNCH CYCLE',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropAssignmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Crop Assignment'),
        const SizedBox(height: 12),

        // Toggle: New crop vs Join existing
        Row(
          children: [
            Expanded(
              child: _cropChoiceTile(
                label: 'New Crop',
                sublabel: 'Start a fresh season',
                icon: Icons.add_circle_outline_rounded,
                selected: !_joinExisting,
                onTap: () => setState(() {
                  _joinExisting = false;
                  _selectedCycleId = null;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _cropChoiceTile(
                label: 'Join Existing',
                sublabel: '${_activeCycles.length} active',
                icon: Icons.link_rounded,
                selected: _joinExisting,
                onTap: () => setState(() {
                  _joinExisting = true;
                  if (_activeCycles.isNotEmpty) {
                    _selectedCycleId ??= _activeCycles.first.id;
                  }
                }),
              ),
            ),
          ],
        ),

        // Cycle selector when joining
        if (_joinExisting) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCycleId,
            decoration: InputDecoration(
              prefixIcon:
                  const Icon(Icons.playlist_add_check, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              labelText: 'Select Crop',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300)),
            ),
            items: _activeCycles.map((c) {
              final doc = c.stockingDate != null
                  ? DateTime.now()
                          .difference(c.stockingDate!)
                          .inDays +
                      1
                  : 0;
              final suggested = doc <= 10;
              return DropdownMenuItem(
                value: c.id,
                child: Row(
                  children: [
                    Expanded(
                        child: Text(c.name,
                            overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    if (suggested)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('DOC $doc',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold)),
                      )
                    else
                      Text('DOC $doc',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) =>
                setState(() => _selectedCycleId = val),
            validator: (val) => _joinExisting && val == null
                ? 'Select a crop to join'
                : null,
          ),
        ],
      ],
    );
  }

  Widget _cropChoiceTile({
    required String label,
    required String sublabel,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).primaryColor.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: selected
                              ? Theme.of(context).primaryColor
                              : Colors.black87)),
                  Text(sublabel,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) => Text(
        label,
        style: TextStyle(
            fontWeight: FontWeight.bold, color: Colors.grey.shade700),
      );

  Widget _inputContainer({required Widget child}) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: child,
      );

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon,
      {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
          validator: (val) =>
              val == null || val.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildFeedBrandDropdown() {
    final feedBrandsAsync = ref.watch(feedBrandsProvider);
    return feedBrandsAsync.when(
      loading: () => _inputContainer(
        child: const SizedBox(
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, st) => _inputContainer(
        child: Text('Error loading feed brands',
            style: TextStyle(color: Colors.red.shade700)),
      ),
      data: (brands) => DropdownButtonFormField<String>(
        value: _selectedFeedBrandId,
        decoration: InputDecoration(
          prefixIcon:
              const Icon(Icons.store_rounded, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          hintText: 'Select a feed brand',
        ),
        items: brands
            .map((brand) => DropdownMenuItem(
                  value: brand.id,
                  child: Text(brand.name),
                ))
            .toList(),
        onChanged: (value) =>
            setState(() => _selectedFeedBrandId = value),
        validator: (value) =>
            value == null ? 'Please select a feed brand' : null,
      ),
    );
  }
}
