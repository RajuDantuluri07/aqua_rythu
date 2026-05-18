import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/expense_model.dart';
import '../../core/models/crop_cycle.dart';
import '../../core/services/pond_service.dart';
import '../../core/services/crop_cycle_service.dart';
import '../../core/services/expense_service.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/uuid_generator.dart';
import 'expense_provider.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  /// Pre-selected crop ID. When null the screen loads active cycles and lets
  /// the farmer pick. When only one active cycle exists it is auto-selected.
  final String? cropId;
  final String farmId;

  const AddExpenseScreen({
    super.key,
    this.cropId,
    required this.farmId,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  ExpenseCategory _selectedCategory = ExpenseCategory.labour;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Crop resolution
  List<CropCycle> _activeCycles = [];
  String? _selectedCropId;
  bool _loadingCycles = true;

  // Pond filtering
  List<Map<String, dynamic>> _allPonds = [];
  String? _selectedPondId;
  bool _loadingPonds = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        CropCycleService().getActiveCycles(widget.farmId),
        PondService().getPonds(widget.farmId),
      ]);

      final cycles = results[0] as List<CropCycle>;
      final ponds = results[1] as List<Map<String, dynamic>>;

      String? resolvedCropId = widget.cropId;

      // If no cropId provided, auto-resolve:
      // - single active cycle → auto-select it (no picker needed)
      // - multiple → leave null so picker is shown
      if (resolvedCropId == null && cycles.length == 1) {
        resolvedCropId = cycles.first.id;
      }

      if (mounted) {
        setState(() {
          _activeCycles = cycles;
          _selectedCropId = resolvedCropId;
          _allPonds = ponds;
          _loadingCycles = false;
          _loadingPonds = false;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load expense screen data', e);
      if (mounted) {
        setState(() {
          _loadingCycles = false;
          _loadingPonds = false;
        });
      }
    }
  }

  /// Ponds that belong to the currently selected crop cycle.
  List<Map<String, dynamic>> get _pondsForCrop {
    if (_selectedCropId == null) return _allPonds;
    return _allPonds
        .where((p) => p['active_crop_id'] == _selectedCropId)
        .toList();
  }

  Future<void> _submitExpense() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCropId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a crop before saving.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid amount. Please enter a valid number.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use the service directly so we can supply a resolved cropId
      // without being constrained by the provider family key.
      await ExpenseService().createExpense(
        farmId: widget.farmId,
        cropId: _selectedCropId!,
        pondId: _selectedPondId,
        category: _selectedCategory,
        amount: amount,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        date: _selectedDate,
        operationId: generateUuidV4(),
      );

      // Invalidate the provider so any open summary screen refreshes.
      ref.invalidate(expensesProvider(_selectedCropId!));
      ref.invalidate(expenseSummaryProvider(_selectedCropId!));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Crop selector (only when multiple active cycles) ──
                      if (!_loadingCycles && _activeCycles.length > 1) ...[
                        _buildCropSelector(),
                        const SizedBox(height: 16),
                      ],

                      // Loading indicator for cycles
                      if (_loadingCycles) ...[
                        const InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Loading crop cycles…',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.agriculture),
                          ),
                          child: SizedBox(
                              height: 20,
                              child: LinearProgressIndicator()),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Category
                      DropdownButtonFormField<ExpenseCategory>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: ExpenseCategory.values.map((c) {
                          return DropdownMenuItem(
                              value: c, child: Text(c.label));
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCategory = v!),
                        validator: (v) =>
                            v == null ? 'Please select a category' : null,
                      ),
                      if (_selectedCategory == ExpenseCategory.feed ||
                          _selectedCategory == ExpenseCategory.supplement) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            border: Border.all(color: const Color(0xFFFFB300)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Color(0xFFE65100)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Feed and supplement costs are auto-tracked via Inventory. '
                                  'Only add this expense if it was not already recorded there.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFE65100)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Pond selector (filtered by crop)
                      _buildPondDropdown(),
                      const SizedBox(height: 16),

                      // Amount
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        autofocus: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter an amount';
                          }
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) {
                            return 'Please enter a valid amount greater than 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Date
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 30)),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                              DateFormat('MMM dd, yyyy')
                                  .format(_selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitExpense(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky CTA
            AnimatedPadding(
              duration: const Duration(milliseconds: 100),
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, bottomInset > 0 ? bottomInset + 8 : 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Add Expense',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedCropId,
      decoration: const InputDecoration(
        labelText: 'Select Crop *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.agriculture),
        helperText: 'Multiple active crops — choose which this expense belongs to',
      ),
      items: _activeCycles.map((c) {
        final docLabel = c.stockingDate != null
            ? 'DOC ${DateTime.now().difference(c.stockingDate!).inDays + 1}'
            : '';
        return DropdownMenuItem(
          value: c.id,
          child: Row(
            children: [
              Expanded(
                  child: Text(c.name, overflow: TextOverflow.ellipsis)),
              if (docLabel.isNotEmpty)
                Text(docLabel,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) => setState(() {
        _selectedCropId = v;
        _selectedPondId = null; // reset pond when crop changes
      }),
      validator: (v) => v == null ? 'Please select a crop' : null,
    );
  }

  Widget _buildPondDropdown() {
    if (_loadingPonds) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Pond (Optional)',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.water),
        ),
        child: SizedBox(height: 20, child: LinearProgressIndicator()),
      );
    }

    final ponds = _pondsForCrop;

    if (ponds.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Pond (Optional)',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.water),
          helperText: 'No active ponds in this crop',
        ),
        child: Text('—'),
      );
    }

    return DropdownButtonFormField<String?>(
      value: _selectedPondId,
      decoration: const InputDecoration(
        labelText: 'Pond (Optional)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.water),
        helperText: 'Leave empty for a farm-wide expense',
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All Ponds (Farm-wide)'),
        ),
        ...ponds.map((p) {
          final id = p['id'] as String;
          final name = p['name'] as String? ?? 'Unnamed Pond';
          return DropdownMenuItem<String?>(value: id, child: Text(name));
        }),
      ],
      onChanged: (v) => setState(() => _selectedPondId = v),
    );
  }
}
