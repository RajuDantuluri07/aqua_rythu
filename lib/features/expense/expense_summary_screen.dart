import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/expense_model.dart';
import 'expense_provider.dart';
import 'add_expense_screen.dart';
import '../upgrade/subscription_provider.dart';
import '../upgrade/upgrade_to_pro_screen.dart';

class ExpenseSummaryScreen extends ConsumerStatefulWidget {
  final String cropId;
  final String farmId;

  const ExpenseSummaryScreen({
    super.key,
    required this.cropId,
    required this.farmId,
  });

  @override
  ConsumerState<ExpenseSummaryScreen> createState() =>
      _ExpenseSummaryScreenState();
}

class _ExpenseSummaryScreenState extends ConsumerState<ExpenseSummaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  Widget _buildExpenseList(List<ExpenseSummary> expenses, String title) {
    if (expenses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No expenses yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start adding expenses to see them here',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total =
        expenses.fold<double>(0, (sum, expense) => sum + expense.totalAmount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${_formatCurrency(total)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue[600],
              ),
            ),
            const SizedBox(height: 16),
            ...expenses.map((expense) {
              final category = ExpenseCategory.fromString(expense.category);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getCategoryIcon(category),
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          category.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatCurrency(expense.totalAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyView(List<WeeklyExpenseSummary> weeklySummaries) {
    if (weeklySummaries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No monthly expenses',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total = weeklySummaries.fold<double>(
      0,
      (sum, week) => sum + week.totalAmount,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Month: ${_formatCurrency(total)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...weeklySummaries.asMap().entries.map((entry) {
              final index = entry.key;
              final week = entry.value;
              final weekDate = DateTime.parse(week.weekStart);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Week ${index + 1} (${DateFormat('MMM dd').format(weekDate)})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatCurrency(week.totalAmount),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...week.categoryBreakdown.map((expense) {
                      final category =
                          ExpenseCategory.fromString(expense.category);
                      return Padding(
                        padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              category.label,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              _formatCurrency(expense.totalAmount),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.labour:
        return Icons.people;
      case ExpenseCategory.electricity:
        return Icons.bolt;
      case ExpenseCategory.diesel:
        return Icons.local_gas_station;
      case ExpenseCategory.sampling:
        return Icons.science;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(isProProvider)) {
      return _ProRequired(
        onUpgrade: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UpgradeToProScreen()),
        ),
      );
    }

    final summaryAsync = ref.watch(expenseSummaryProvider(widget.cropId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Summary'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref
                  .read(expenseSummaryProvider(widget.cropId).notifier)
                  .refresh();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(
                cropId: widget.cropId,
                farmId: widget.farmId,
              ),
            ),
          );
        },
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.add),
      ),
      body: summaryAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading expenses',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(expenseSummaryProvider(widget.cropId).notifier)
                      .refresh();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (summary) {
          final dailyExpenses = summary['daily'] as List<ExpenseSummary>;
          final weeklyExpenses = summary['weekly'] as List<ExpenseSummary>;
          final monthlyExpenses =
              summary['monthly'] as List<WeeklyExpenseSummary>;

          return TabBarView(
            controller: _tabController,
            children: [
              // Daily View
              RefreshIndicator(
                onRefresh: () async {
                  await ref
                      .read(expenseSummaryProvider(widget.cropId).notifier)
                      .refresh();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: _buildExpenseList(
                    dailyExpenses,
                    'Today',
                  ),
                ),
              ),
              // Weekly View
              RefreshIndicator(
                onRefresh: () async {
                  await ref
                      .read(expenseSummaryProvider(widget.cropId).notifier)
                      .refresh();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: _buildExpenseList(
                    weeklyExpenses,
                    'This Week',
                  ),
                ),
              ),
              // Monthly View
              RefreshIndicator(
                onRefresh: () async {
                  await ref
                      .read(expenseSummaryProvider(widget.cropId).notifier)
                      .refresh();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: _buildMonthlyView(monthlyExpenses),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProRequired extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _ProRequired({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Summary'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE8A33D), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.workspace_premium_rounded,
                      size: 36, color: Color(0xFFE8A33D)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'PRO Feature',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0E1A1F)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Log daily expenses and see where your money goes — feed, labour, diesel, and more.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A5560),
                    height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onUpgrade,
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: const Text('Upgrade to PRO — ₹999/crop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8A33D),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe Later',
                    style: TextStyle(color: Color(0xFF4A5560))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
