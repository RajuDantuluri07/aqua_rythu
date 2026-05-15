import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_brand.dart';
import '../models/feed_master_product.dart';
import '../models/master_category.dart';
import '../models/product_master.dart';
import '../models/supplement_schedule.dart';
import '../repositories/category_repository.dart';
import '../repositories/feed_brand_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/schedule_repository.dart';

final _repo = ProductRepository();
final _categoryRepo = CategoryRepository();
final _scheduleRepo = ScheduleRepository();
final _feedBrandRepo = FeedBrandRepository();

/// All active feed brands/products from feed_master_products.
final feedProductsProvider = FutureProvider<List<FeedMasterProduct>>((ref) {
  return _repo.fetchFeedProducts();
});

/// All active products from product_master (supplements, minerals, etc.).
final allProductsProvider = FutureProvider<List<ProductMaster>>((ref) {
  return _repo.fetchAllProducts();
});

/// Products filtered to a specific set of categories.
/// Pass the category list as the family argument.
final productsByCategoriesProvider =
    FutureProvider.family<List<ProductMaster>, List<String>>(
        (ref, categories) async {
  if (categories.isEmpty) return [];
  return _repo.fetchProductsByCategories(categories);
});

/// Categories for feed_mix (feed_mix + both)
final feedCategoriesProvider = FutureProvider<List<MasterCategory>>((ref) {
  return _categoryRepo.fetchCategoriesByType('feed_mix');
});

/// Categories for water_mix (water_mix + both)
final waterCategoriesProvider = FutureProvider<List<MasterCategory>>((ref) {
  return _categoryRepo.fetchCategoriesByType('water_mix');
});

/// All active categories regardless of application type
final allCategoriesProvider = FutureProvider<List<MasterCategory>>((ref) {
  return _categoryRepo.fetchAllCategories();
});

/// Products filtered to a single category name
final productsByCategoryProvider =
    FutureProvider.family<List<ProductMaster>, String>((ref, categoryName) async {
  if (categoryName.isEmpty) return [];
  return _repo.fetchProductsByCategory(categoryName);
});

/// Supplement schedules for a specific pond
final supplementSchedulesProvider =
    FutureProvider.family<List<SupplementSchedule>, String>((ref, pondId) {
  return _scheduleRepo.fetchSchedulesByPond(pondId);
});

/// Active supplement schedules for a specific pond
final activeSupplementSchedulesProvider =
    FutureProvider.family<List<SupplementSchedule>, String>((ref, pondId) {
  return _scheduleRepo.fetchActiveSchedulesByPond(pondId);
});

/// All active feed brands from feed_master_products table
final feedBrandsProvider = FutureProvider<List<FeedBrand>>((ref) {
  return _feedBrandRepo.fetchAllBrands();
});
