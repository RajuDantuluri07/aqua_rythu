import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feed_master_product.dart';
import '../models/product_master.dart';
import '../utils/logger.dart';

class ProductRepository {
  final _supabase = Supabase.instance.client;

  Future<List<FeedMasterProduct>> fetchFeedProducts() async {
    try {
      final rows = await _supabase
          .from('feed_master_products')
          .select()
          .eq('active', true)
          .order('brand')
          .order('product_name');
      return rows.map((r) => FeedMasterProduct.fromJson(r)).toList();
    } catch (e) {
      AppLogger.error('ProductRepository.fetchFeedProducts failed', e);
      return [];
    }
  }

  Future<List<ProductMaster>> fetchProductsByCategories(
      List<String> categories) async {
    try {
      final rows = await _supabase
          .from('product_master')
          .select()
          .eq('active', true)
          .inFilter('category', categories)
          .order('category')
          .order('product_name');
      return rows.map((r) => ProductMaster.fromJson(r)).toList();
    } catch (e) {
      AppLogger.error('ProductRepository.fetchProductsByCategories failed', e);
      return [];
    }
  }

  Future<List<ProductMaster>> fetchAllProducts() async {
    try {
      final rows = await _supabase
          .from('product_master')
          .select()
          .eq('active', true)
          .order('category')
          .order('product_name');
      return rows.map((r) => ProductMaster.fromJson(r)).toList();
    } catch (e) {
      AppLogger.error('ProductRepository.fetchAllProducts failed', e);
      return [];
    }
  }

  Future<List<ProductMaster>> fetchProductsByCategory(String categoryName) async {
    try {
      final rows = await _supabase
          .from('product_master')
          .select()
          .eq('active', true)
          .eq('category', categoryName)
          .order('brand')
          .order('product_name');
      return rows.map((r) => ProductMaster.fromJson(r)).toList();
    } catch (e) {
      AppLogger.error('ProductRepository.fetchProductsByCategory failed', e);
      return [];
    }
  }
}
