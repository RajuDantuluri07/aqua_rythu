import 'package:supabase_flutter/supabase_flutter.dart';

class FarmMember {
  final String id;
  final String farmId;
  final String email;
  final String role;
  final DateTime createdAt;

  FarmMember({
    required this.id,
    required this.farmId,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory FarmMember.fromJson(Map<String, dynamic> j) => FarmMember(
        id: j['id'] as String,
        farmId: j['farm_id'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class FarmMemberService {
  final _db = Supabase.instance.client;

  Future<List<FarmMember>> getMembersForFarm(String farmId) async {
    final data = await _db
        .from('farm_members')
        .select()
        .eq('farm_id', farmId)
        .order('created_at');
    return (data as List).map((e) => FarmMember.fromJson(e)).toList();
  }

  Future<void> addMember({
    required String farmId,
    required String email,
    required String role,
  }) async {
    final user = _db.auth.currentUser;
    await _db.from('farm_members').insert({
      'farm_id': farmId,
      'email': email.trim().toLowerCase(),
      'role': role,
      'invited_by': user?.id,
    });
  }

  Future<void> removeMember(String memberId) async {
    await _db.from('farm_members').delete().eq('id', memberId);
  }
}
