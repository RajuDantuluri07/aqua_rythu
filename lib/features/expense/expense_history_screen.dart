import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/expense_model.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/logger.dart';
import '../farm/farm_provider.dart';
import 'add_expense_screen.dart';
import 'edit_expense_screen.dart';
import 'expense_provider.dart';
import 'widgets/expense_filter_sheet.dart';
import 'widgets/expense_tile.dart';

class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  final String cropId;
  final String farmId;

  const ExpenseHistoryScreen({
    super.key,
    required this.cropId,
    required this.farmId,
  });

  @override
  ConsumerState<ExpenseHistoryScreen> createState() =>
      _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
        AnalyticsService.instance.trackScreen('expense_history_screen'));
  }

  Future<void> _refresh() async {
    ref.invalidate(expensesProvider(widget.cropId));
    // Small delay so the loading state is visible on pull-to-refresh.
    await Future.delayed(const Duration(milliseconds: 400));
  }

  void _openFilter(List<({String id, String name})> ponds) async {
    final current =
        ref.read(expenseFilterProvider(widget.cropId));
    final updated = await ExpenseFilterSheet.show(
      context,
      current: current,
      ponds: ponds,
    );
    if (updated != null && mounted) {
      ref
          .read(expenseFilterProvider(widget.cropId).notifier)
          .state = updated;
    }
  }

  void _openAdd() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          cropId: widget.cropId,
          farmId: widget.farmId,
        ),
      ),
    );
  }

  void _openEdit(Expense expense) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditExpenseScreen(
          cropId: widget.cropId,
          farmId: widget.farmId,
          expense: expense,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmProvider);
    final pondList = farmState.farms
        .where((f) => f.id == widget.farmId)
        .expand((f) => f.ponds)
        .map((p) => (id: p.id, name: p.name))
        .toList();

    final pondNameById = {for (final p in pondList) p.id: p.name};

    final filter = ref.watch(expenseFilterProvider(widget.cropId));
    final expensesAsync =
        ref.watch(filteredExpensesProvider(widget.cropId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Expense History'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Filter button with active badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Filter',
                onPressed: () => _openFilter(pondList),
              ),
              if (filter.isActive)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: Colors.blue.shade600,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: Column(
        children: [
          // Active filter strip
          if (filter.isActive) _buildFilterStrip(filter, pondNameById),

          Expanded(
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(e),
              data: (expenses) => expenses.isEmpty
                  ? _buildEmpty(filter.isActive)
                  : _buildList(expenses, pondNameById),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterStrip(
      ExpenseFilter filter, Map<String, String> pondNameById) {
    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _filterDescription(filter, pondNameById),
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => ref
                .read(expenseFilterProvider(widget.cropId).notifier)
                .state = const ExpenseFilter(),
            child: Icon(Icons.close, size: 16, color: Colors.blue.shade700),
          ),
        ],
      ),
    );
  }

  String _filterDescription(
      ExpenseFilter filter, Map<String, String> pondNameById) {
    final parts = <String>[];
    if (filter.category != null) parts.add(filter.category!.label);
    if (filter.pondId != null) {
      parts.add(pondNameById[filter.pondId] ?? 'Pond');
    }
    if (filter.dateRange != null) {
      final fmt = DateFormat('dd MMM');
      parts.add(
          '${fmt.format(filter.dateRange!.start)} – ${fmt.format(filter.dateRange!.end)}');
    }
    return 'Filtered: ${parts.join(', ')}';
  }

  Widget _buildList(
      List<Expense> expenses, Map<String, String> pondNameById) {
    // Group by date
    final grouped = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      final day = DateUtils.dateOnly(e.date);
      grouped.putIfAbsent(day, () => []).add(e);
    }
    final days = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // newest first

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: days.length,
        itemBuilder: (context, idx) {
          final day = days[idx];
          final dayExpenses = grouped[day]!;
          final dayTotal =
              dayExpenses.fold<double>(0, (s, e) => s + e.amount);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDayHeader(day),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      '₹${dayTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // Expense tiles
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                color: Colors.white,
                child: Column(
                  children: [
                    for (var i = 0; i < dayExpenses.length; i++) ...[
                      ExpenseTile(
                        expense: dayExpenses[i],
                        pondName: dayExpenses[i].pondId != null
                            ? pondNameById[dayExpenses[i].pondId]
                            : null,
                        onTap: () => _openEdit(dayExpenses[i]),
                      ),
                      if (i < dayExpenses.length - 1)
                        Divider(
                          height: 1,
                          indent: 74,
                          color: Colors.grey.shade100,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDayHeader(DateTime day) {
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'TODAY';
    if (day == yesterday) return 'YESTERDAY';
    return DateFormat('EEE, dd MMM yyyy').format(day).toUpperCase();
  }

  Widget _buildEmpty(bool isFiltered) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFiltered
                        ? Icons.search_off_rounded
                        : Icons.receipt_long_outlined,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isFiltered
                      ? 'No expenses match filters'
                      : 'No expenses yet',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isFiltered
                      ? 'Try removing or changing the filters'
                      : 'Tap + Add Expense to log your first expense',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isFiltered) ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => ref
                        .read(expenseFilterProvider(widget.cropId).notifier)
                        .state = const ExpenseFilter(),
                    child: const Text('Clear Filters'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object e) {
    AppLogger.error('ExpenseHistoryScreen error', e);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          const Text('Could not load expenses',
              style: TextStyle(fontSize: 16, color: Color(0xFF475569))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(expensesProvider(widget.cropId)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
