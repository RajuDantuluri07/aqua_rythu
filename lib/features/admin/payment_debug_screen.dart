import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Available in debug builds only — the route is never registered in release.

class PaymentDebugScreen extends StatefulWidget {
  const PaymentDebugScreen({super.key});

  @override
  State<PaymentDebugScreen> createState() => _PaymentDebugScreenState();
}

class _PaymentDebugScreenState extends State<PaymentDebugScreen> {
  static const _green = Color(0xFF1B8A4C);

  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _error;

  // Filter by user_id — defaults to the signed-in user
  final _userIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userIdCtrl.text =
        Supabase.instance.client.auth.currentUser?.id ?? '';
    _loadLogs();
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _userIdCtrl.text.trim();
      final rows = await (userId.isNotEmpty
              ? Supabase.instance.client
                  .from('payment_logs')
                  .select()
                  .eq('user_id', userId)
                  .order('created_at', ascending: false)
                  .limit(100)
              : Supabase.instance.client
                  .from('payment_logs')
                  .select()
                  .order('created_at', ascending: false)
                  .limit(100))
          as List<dynamic>;
      setState(() {
        _logs = rows.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only render in debug builds — belt-and-suspenders beyond the route guard.
    if (kReleaseMode) {
      return const Scaffold(
        body: Center(child: Text('Not available')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Payment Logs',
          style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 17,
              fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _userIdCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Filter by user_id (UUID)',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _loadLogs,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _green));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _loadLogs, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_logs.isEmpty) {
      return const Center(
        child: Text('No payment logs found.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _LogCard(log: _logs[i]),
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final status = log['status'] as String? ?? '—';
    final source = log['source'] as String? ?? '—';
    final paymentId = log['payment_id'] as String? ?? '—';
    final orderId = log['order_id'] as String? ?? '—';
    final error = log['error_message'] as String?;
    final createdAt = log['created_at'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _statusColor(status).withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(status: status),
              const SizedBox(width: 8),
              _SourceChip(source: source),
              const Spacer(),
              Text(
                _shortTs(createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _copyRow(context, 'Payment ID', paymentId),
          const SizedBox(height: 4),
          _copyRow(context, 'Order ID', orderId),
          if (error != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(error,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.red, height: 1.4)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _copyRow(BuildContext context, String label, String value) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copied'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.copy_rounded, size: 12, color: Colors.grey),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'success' => const Color(0xFF22C55E),
      'failed' => Colors.red,
      'retry' => Colors.orange,
      'webhook_received' => Colors.blue,
      _ => Colors.grey,
    };
  }

  String _shortTs(String iso) {
    if (iso.length < 19) return iso;
    return iso.substring(0, 19).replaceFirst('T', ' ');
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Color _color() => switch (status) {
        'success' => const Color(0xFF22C55E),
        'failed' => Colors.red,
        'retry' => Colors.orange,
        'webhook_received' => Colors.blue,
        _ => Colors.grey,
      };
}

class _SourceChip extends StatelessWidget {
  final String source;
  const _SourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    final isWebhook = source == 'webhook';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: (isWebhook ? Colors.purple : Colors.teal).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        source.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isWebhook ? Colors.purple : Colors.teal,
        ),
      ),
    );
  }
}
