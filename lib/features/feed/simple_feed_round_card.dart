import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FeedRoundStatus { current, done, upcoming }

class SimpleFeedRoundCard extends ConsumerStatefulWidget {
  final int round;
  final String time;
  final double feedQty;
  final FeedRoundStatus status;
  final int doc; // Days of culture
  final VoidCallback? onEdit;
  final VoidCallback? onMarkAsFed;
  final Function(String)? onTrayCondition;

  const SimpleFeedRoundCard({
    super.key,
    required this.round,
    required this.time,
    required this.feedQty,
    required this.status,
    required this.doc,
    this.onEdit,
    this.onMarkAsFed,
    this.onTrayCondition,
  });

  @override
  ConsumerState<SimpleFeedRoundCard> createState() => _SimpleFeedRoundCardState();
}

class _SimpleFeedRoundCardState extends ConsumerState<SimpleFeedRoundCard> {
  bool _isSubmitting = false;

  Color _getStatusColor() {
    switch (widget.status) {
      case FeedRoundStatus.current:
        return Colors.green;
      case FeedRoundStatus.done:
        return Colors.grey;
      case FeedRoundStatus.upcoming:
        return Colors.blue;
    }
  }

  String _getStatusText() {
    switch (widget.status) {
      case FeedRoundStatus.current:
        return "CURRENT";
      case FeedRoundStatus.done:
        return "DONE";
      case FeedRoundStatus.upcoming:
        return "UPCOMING";
    }
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor(), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _getStatusColor(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _getStatusText(),
            style: TextStyle(
              color: _getStatusColor(),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showTrayConditionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tray Condition"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("How was the tray condition?"),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTrayOption("Leftover", Icons.restaurant),
                _buildTrayOption("Normal", Icons.check_circle),
                _buildTrayOption("Empty fast", Icons.speed),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Widget _buildTrayOption(String condition, IconData icon) {
    return GestureDetector(
      onTap: () {
        if (widget.onTrayCondition != null) {
          widget.onTrayCondition!(condition);
        }
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Icon(icon, size: 24, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            condition,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmartFeeding = widget.doc > 30;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.status == FeedRoundStatus.current 
              ? Colors.green 
              : Colors.grey[300]!,
          width: widget.status == FeedRoundStatus.current ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ROUND ${widget.round} • ${widget.time}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusBadge(),
                  ],
                ),
                // Edit button - always visible especially for DOC > 30
                if (widget.onEdit != null && widget.doc > 30)
                  IconButton(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
              ],
            ),
          ),
          
          // MAIN VALUE - Center focus
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Text(
                  "${widget.feedQty.toStringAsFixed(1)} kg",
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                // Show feeding type based on DOC
                Text(
                  isSmartFeeding ? "(Suggested)" : "(Blind plan)",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // PRIMARY ACTION
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: _buildActionButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    switch (widget.status) {
      case FeedRoundStatus.current:
        return ElevatedButton(
          onPressed: _isSubmitting 
            ? null 
            : () async {
                if (widget.onMarkAsFed != null) {
                  setState(() => _isSubmitting = true);
                  widget.onMarkAsFed!();
                  
                  // Show tray condition dialog after marking as fed
                  if (widget.doc > 30 && widget.onTrayCondition != null) {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _showTrayConditionDialog();
                    });
                  }
                  
                  if (mounted) setState(() => _isSubmitting = false);
                }
              },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                "MARK AS FED",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
        );
        
      case FeedRoundStatus.done:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                "FED",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        );
        
      case FeedRoundStatus.upcoming:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: const Text(
            "UPCOMING",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0284C7),
            ),
            textAlign: TextAlign.center,
          ),
        );
    }
  }
}
