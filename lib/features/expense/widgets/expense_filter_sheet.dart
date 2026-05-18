import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/expense_model.dart';
import '../expense_provider.dart';

class ExpenseFilterSheet extends StatefulWidget {
  final ExpenseFilter initial;
  final List<({String id, String name})> ponds;

  const ExpenseFilterSheet({
    super.key,
    required this.initial,
    required this.ponds,
  });

  /// Opens the filter sheet and returns the updated filter, or null if dismissed.
  static Future<ExpenseFilter?> show(
    BuildContext context, {
    required ExpenseFilter current,
    required List<({String id, String name})> ponds,
  }) {
    return showModalBottomSheet<ExpenseFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpenseFilterSheet(initial: current, ponds: ponds),
    );
  }

  @override
  State<ExpenseFilterSheet> createState() => _ExpenseFilterSheetState();
}

class _ExpenseFilterSheetState extends State<ExpenseFilterSheet> {
  late ExpenseCategory? _category;
  late String? _pondId;
  late DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _category = widget.initial.category;
    _pondId = widget.initial.pondId;
    _dateRange = widget.initial.dateRange;
  }

  bool get _hasChanges =>
      _category != widget.initial.category ||
      _pondId != widget.initial.pondId ||
      _dateRange != widget.initial.dateRange;

  bool get _isActive =>
      _category != null || _pondId != null || _dateRange != null;

  void _clear() => setState(() {
        _category = null;
        _pondId = null;
        _dateRange = null;
      });

  void _apply() => Navigator.of(context).pop(
        ExpenseFilter(
          category: _category,
          pondId: _pondId,
          dateRange: _dateRange,
        ),
      );

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: Colors.blue.shade600),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const Text(
                'Filter Expenses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_isActive)
                TextButton(
                  onPressed: _clear,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear all'),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Category
          const Text(
            'CATEGORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ExpenseCategory.values.map((cat) {
              final selected = _category == cat;
              return GestureDetector(
                onTap: () =>
                    setState(() => _category = selected ? null : cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? cat.color.withOpacity(0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? cat.color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon,
                          size: 14,
                          color: selected ? cat.color : Colors.grey.shade500),
                      const SizedBox(width: 5),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected ? cat.color : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Pond
          if (widget.ponds.isNotEmpty) ...[
            const Text(
              'POND',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              value: _pondId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                prefixIcon:
                    const Icon(Icons.water_outlined, size: 20),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All ponds'),
                ),
                ...widget.ponds.map((p) => DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text(p.name),
                    )),
              ],
              onChanged: (v) => setState(() => _pondId = v),
            ),
            const SizedBox(height: 20),
          ],

          // Date range
          const Text(
            'DATE RANGE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _dateRange != null
                      ? Colors.blue.shade400
                      : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(10),
                color: _dateRange != null
                    ? Colors.blue.shade50
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range_outlined,
                    size: 20,
                    color: _dateRange != null
                        ? Colors.blue.shade600
                        : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dateRange != null
                          ? '${DateFormat('dd MMM').format(_dateRange!.start)} – ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}'
                          : 'Select date range',
                      style: TextStyle(
                        fontSize: 14,
                        color: _dateRange != null
                            ? Colors.blue.shade700
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  if (_dateRange != null)
                    GestureDetector(
                      onTap: () => setState(() => _dateRange = null),
                      child: Icon(Icons.close,
                          size: 18, color: Colors.grey.shade400),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                _hasChanges ? 'Apply Filter' : 'Done',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
