import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/master_category.dart';

class CategoryRepository {
  final _supabase = Supabase.instance.client;

  Future<List<MasterCategory>> fetchCategoriesByType(String applicationType) async {
    try {
      final response = await _supabase
          .from('master_categories')
          .select()
          .inFilter('default_application_type', [applicationType, 'both'])
          .eq('active', true)
          .order('sort_order');

      return (response as List)
          .map((json) => MasterCategory.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<MasterCategory>> fetchAllCategories() async {
    try {
      final response = await _supabase
          .from('master_categories')
          .select()
          .eq('active', true)
          .order('sort_order');

      return (response as List)
          .map((json) => MasterCategory.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<MasterCategory?> fetchCategoryByName(String name) async {
    try {
      final response = await _supabase
          .from('master_categories')
          .select()
          .eq('name', name)
          .eq('active', true)
          .maybeSingle();

      if (response == null) return null;
      return MasterCategory.fromJson(response);
    } catch (_) {
      return null;
    }
  }
}
