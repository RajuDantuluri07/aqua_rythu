import 'package:flutter/material.dart';
import 'package:aqua_rythu/core/services/farm/farm_member_service.dart';
import 'package:aqua_rythu/features/farm/farm_provider.dart';
import 'add_member_sheet.dart';

class FarmDetailSheet extends StatefulWidget {
  final Farm farm;

  const FarmDetailSheet({super.key, required this.farm});

  @override
  State<FarmDetailSheet> createState() => _FarmDetailSheetState();
}

class _FarmDetailSheetState extends State<FarmDetailSheet> {
  static const _primaryGreen = Color(0xFF1B8A4C);

  late Future<List<FarmMember>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _loadMembers() {
    _membersFuture =
        FarmMemberService().getMembersForFarm(widget.farm.id);
  }

  double get _totalArea =>
      widget.farm.ponds.fold(0.0, (sum, p) => sum + p.area);

  String _roleLabel(String role) {
    switch (role) {
      case 'farmer':
        return 'Farmer';
      case 'partner':
        return 'Partner';
      case 'supervisor':
        return 'Supervisor';
      case 'worker':
        return 'Worker';
      default:
        return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'farmer':
        return _primaryGreen;
      case 'partner':
        return const Color(0xFF1565C0);
      case 'supervisor':
        return const Color(0xFFE65100);
      case 'worker':
        return const Color(0xFF6A1B9A);
      default:
        return Colors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'farmer':
        return Icons.agriculture_outlined;
      case 'partner':
        return Icons.handshake_outlined;
      case 'supervisor':
        return Icons.manage_accounts_outlined;
      case 'worker':
        return Icons.engineering_outlined;
      default:
        return Icons.person_outline;
    }
  }

  void _openAddMember() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMemberSheet(
        farmId: widget.farm.id,
        farmName: widget.farm.name,
        onAdded: () => setState(_loadMembers),
      ),
    );
  }

  Future<void> _deleteMember(String memberId) async {
    try {
      await FarmMemberService().removeMember(memberId);
      setState(_loadMembers);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF2F4F6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.farm.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: Color(0xFF888888)),
                            const SizedBox(width: 3),
                            Text(
                              widget.farm.location,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF888888)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Stats row
                  Row(
                    children: [
                      _statCard(
                        Icons.water_outlined,
                        widget.farm.ponds.length.toString(),
                        'Ponds',
                        const Color(0xFFE3F2FD),
                        const Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        Icons.straighten_outlined,
                        '${_totalArea.toStringAsFixed(1)} ac',
                        'Total Area',
                        const Color(0xFFE8F5EE),
                        _primaryGreen,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Members section header
                  Row(
                    children: [
                      const Text(
                        'MEMBERS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _openAddMember,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _primaryGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_add_outlined,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                'Add Member',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Members list
                  FutureBuilder<List<FarmMember>>(
                    future: _membersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                                color: _primaryGreen, strokeWidth: 2),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error loading members',
                              style: TextStyle(color: Colors.red.shade400)),
                        );
                      }
                      final members = snapshot.data ?? [];
                      if (members.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: const Color(0xFFE8ECF0)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.group_outlined,
                                  size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              const Text(
                                'No members yet',
                                style: TextStyle(color: Color(0xFF888888)),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tap "Add Member" to invite people',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFFAAAAAA)),
                              ),
                            ],
                          ),
                        );
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8ECF0)),
                        ),
                        child: Column(
                          children: members.asMap().entries.map((entry) {
                            final i = entry.key;
                            final m = entry.value;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: _roleColor(m.role)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(_roleIcon(m.role),
                                            color: _roleColor(m.role),
                                            size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m.email,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _roleColor(m.role)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                _roleLabel(m.role),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: _roleColor(m.role),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Color(0xFFCCCCCC)),
                                        onPressed: () =>
                                            _deleteMember(m.id),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                                if (i < members.length - 1)
                                  const Divider(
                                      height: 1,
                                      thickness: 1,
                                      indent: 64,
                                      color: Color(0xFFF0F0F0)),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Add Member CTA button (bottom)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _openAddMember,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text('Add Member',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      IconData icon, String value, String label, Color bg, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8ECF0)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF888888))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
