import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feed_brand.dart';

class FeedBrandRepository {
  final _supabase = Supabase.instance.client;

  Future<List<FeedBrand>> fetchAllBrands() async {
    try {
      final response = await _supabase
          .from('feed_master_products')
          .select('id, brand')
          .eq('active', true)
          .order('brand', ascending: true);

      // Get distinct brands
      final Map<String, FeedBrand> brandMap = {};
      for (final row in response as List) {
        final id = row['id'] as String;
        final brand = row['brand'] as String;
        if (!brandMap.containsKey(brand)) {
          brandMap[brand] = FeedBrand(
            id: id,
            name: brand,
            defaultPricePerKg: 45.0, // Default estimate for now
          );
        }
      }

      return brandMap.values.toList();
    } catch (e) {
      return [];
    }
  }

  Future<FeedBrand?> getBrandById(String brandId) async {
    try {
      final response = await _supabase
          .from('feed_master_products')
          .select()
          .eq('id', brandId)
          .eq('active', true)
          .maybeSingle();

      if (response == null) return null;
      return FeedBrand.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<FeedBrand?> getBrandByName(String brandName) async {
    try {
      final response = await _supabase
          .from('feed_master_products')
          .select()
          .eq('brand', brandName)
          .eq('active', true)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return FeedBrand.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
