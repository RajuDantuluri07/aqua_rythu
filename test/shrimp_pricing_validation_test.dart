import 'package:flutter_test/flutter_test.dart';
import '../lib/core/models/shrimp_pricing.dart';

/// Test cases for shrimp pricing validation
///
/// These tests verify that the validation logic works correctly
/// to prevent bad manual entries in the admin panel
void main() {
  group('Shrimp Pricing Validation Tests', () {
    test('Valid pricing should pass validation', () {
      final validConfig = ShrimpPricingConfig(
        pricingTiers: [
          const ShrimpPricing(count: 100, price: 270),
          const ShrimpPricing(count: 90, price: 280),
          const ShrimpPricing(count: 80, price: 300),
        ],
        enabled: true,
      );

      final result =
          ShrimpPricingValidator.validatePricingTiers(validConfig.pricingTiers);
      expect(result, isNull, reason: 'Valid pricing should pass validation');
    });

    test('Price below minimum should fail', () {
      final invalidConfig = ShrimpPricingConfig(
        pricingTiers: [
          const ShrimpPricing(count: 100, price: 50), // Too low
          const ShrimpPricing(count: 90, price: 280),
        ],
        enabled: true,
      );

      final result = ShrimpPricingValidator.validatePricingTiers(
          invalidConfig.pricingTiers);
      expect(result, isNotNull, reason: 'Price below minimum should fail');
      expect(result, contains('at least 0'),
          reason: 'Should mention minimum price');
    });

    test('Price above maximum should fail', () {
      final invalidConfig = ShrimpPricingConfig(
        pricingTiers: [
          const ShrimpPricing(count: 100, price: 15000), // Too high
          const ShrimpPricing(count: 90, price: 280),
        ],
        enabled: true,
      );

      final result = ShrimpPricingValidator.validatePricingTiers(
          invalidConfig.pricingTiers);
      expect(result, isNotNull, reason: 'Price above maximum should fail');
      expect(result, contains('exceed'),
          reason: 'Should mention maximum price');
    });

    test('Duplicate counts should fail', () {
      final invalidConfig = ShrimpPricingConfig(
        pricingTiers: [
          const ShrimpPricing(count: 100, price: 270),
          const ShrimpPricing(count: 100, price: 280), // Duplicate
        ],
        enabled: true,
      );

      final result = ShrimpPricingValidator.validatePricingTiers(
          invalidConfig.pricingTiers);
      expect(result, isNotNull, reason: 'Duplicate counts should fail');
      expect(result, contains('duplicate'),
          reason: 'Should mention duplicate counts');
    });

    test('Invalid count should fail', () {
      final invalidConfig = ShrimpPricingConfig(
        pricingTiers: [
          const ShrimpPricing(count: 95, price: 270), // Not in valid list
          const ShrimpPricing(count: 90, price: 280),
        ],
        enabled: true,
      );

      final result = ShrimpPricingValidator.validatePricingTiers(
          invalidConfig.pricingTiers);
      expect(result, isNotNull, reason: 'Invalid count should fail');
      expect(result, contains('Invalid count'),
          reason: 'Should mention invalid count');
    });

    test('Empty pricing list should fail', () {
      final result = ShrimpPricingValidator.validatePricingTiers([]);
      expect(result, isNotNull, reason: 'Empty pricing list should fail');
      expect(result, contains('required'),
          reason: 'Should mention at least one tier');
    });

    test('Valid price string validation', () {
      expect(ShrimpPricingValidator.validatePrice('270'), isNull,
          reason: 'Valid price should pass');
      expect(ShrimpPricingValidator.validatePrice('270.5'), isNull,
          reason: 'Valid decimal price should pass');
      expect(ShrimpPricingValidator.validatePrice(''), 'Price is required',
          reason: 'Empty price should fail');
      expect(
          ShrimpPricingValidator.validatePrice('abc'), 'Invalid price format',
          reason: 'Non-numeric should fail');
      expect(ShrimpPricingValidator.validatePrice('-100'), 'at least 0',
          reason: 'Negative price should fail');
    });

    test('Valid count validation', () {
      expect(ShrimpPricingValidator.validateCount(100), isNull,
          reason: 'Valid count should pass');
      expect(ShrimpPricingValidator.validateCount(25), isNull,
          reason: 'Valid count should pass');
      expect(ShrimpPricingValidator.validateCount(95), isNotNull,
          reason: 'Invalid count should fail');
      expect(ShrimpPricingValidator.validateCount(null), 'Count is required',
          reason: 'Null count should fail');
    });

    test('Default config should be valid', () {
      final defaultConfig = ShrimpPricingConfig.defaultConfig();

      final result = ShrimpPricingValidator.validatePricingTiers(
          defaultConfig.pricingTiers);
      expect(result, isNull, reason: 'Default config should be valid');

      expect(defaultConfig.pricingTiers.length, 11,
          reason: 'Should have 11 pricing tiers');
      expect(defaultConfig.enabled, isTrue,
          reason: 'Should be enabled by default');
      expect(defaultConfig.currency, 'INR', reason: 'Should default to INR');
    });

    test('Price lookup should work correctly', () {
      final config = ShrimpPricingConfig(
        pricingTiers: [
          const ShrimpPricing(count: 100, price: 270),
          const ShrimpPricing(count: 90, price: 280),
          const ShrimpPricing(count: 80, price: 300),
        ],
        enabled: true,
      );

      expect(config.getPriceForCount(100), 270,
          reason: 'Exact match should work');
      expect(config.getPriceForCount(95), 270,
          reason: 'Should find closest lower tier');
      expect(config.getPriceForCount(85), 280,
          reason: 'Should find closest lower tier');
      expect(config.getPriceForCount(75), 300,
          reason: 'Should find closest lower tier');
      expect(config.getPriceForCount(70), isNull,
          reason: 'Should return null if no tier available');
    });

    test('Sorted tiers should be in descending order', () {
      final config = ShrimpPricingConfig(
        pricingTiers: [
          const ShrimpPricing(count: 25, price: 540),
          const ShrimpPricing(count: 100, price: 270),
          const ShrimpPricing(count: 50, price: 340),
        ],
        enabled: true,
      );

      final sortedTiers = config.sortedTiers;

      expect(sortedTiers[0].count, 100,
          reason: 'First should be highest count');
      expect(sortedTiers[1].count, 50, reason: 'Second should be middle count');
      expect(sortedTiers[2].count, 25, reason: 'Third should be lowest count');
    });

    // MANDATORY ORDER RULE TESTS
    test('Correct order should pass validation', () {
      final validConfig = ShrimpPricingConfig(
        pricingTiers: [
          const ShrimpPricing(count: 100, price: 270),
          const ShrimpPricing(count: 90, price: 280),
          const ShrimpPricing(count: 80, price: 300),
        ],
        enabled: true,
      );

      final result =
          ShrimpPricingValidator.validatePricingTiers(validConfig.pricingTiers);
      expect(result, isNull,
          reason:
              'Correct order (Count: 100->90->80, Price: 270->280->300) should pass');
    });

    test('Wrong count order should fail', () {
      final invalidConfig = ShrimpPricingConfig(
        pricingTiers: [
          const ShrimpPricing(count: 100, price: 270),
          const ShrimpPricing(count: 110, price: 280), // Count increased
          const ShrimpPricing(count: 80, price: 300),
        ],
        enabled: true,
      );

      final result = ShrimpPricingValidator.validatePricingTiers(
          invalidConfig.pricingTiers);
      expect(result, isNotNull, reason: 'Wrong count order should fail');
      expect(result, contains('descending order'),
          reason: 'Should mention descending order requirement');
    });

    test('Wrong price order should fail', () {
      final invalidConfig = ShrimpPricingConfig(
        pricingTiers: [
          const ShrimpPricing(count: 100, price: 270),
          const ShrimpPricing(count: 90, price: 260), // Price decreased
          const ShrimpPricing(count: 80, price: 300),
        ],
        enabled: true,
      );

      final result = ShrimpPricingValidator.validatePricingTiers(
          invalidConfig.pricingTiers);
      expect(result, isNotNull, reason: 'Wrong price order should fail');
      expect(result, contains('Price must increase'),
          reason: 'Should mention price increase requirement');
      expect(result, contains('100 -> 90'),
          reason: 'Should show the problematic count transition');
      expect(result, contains('270 -> 260'),
          reason: 'Should show the problematic price transition');
    });

    test('Both count and price wrong order should fail', () {
      final invalidConfig = ShrimpPricingConfig(
        pricingTiers: [
          const ShrimpPricing(
              count: 80, price: 300), // Started with wrong order
          const ShrimpPricing(
              count: 100, price: 270), // Count increased, price decreased
          const ShrimpPricing(count: 90, price: 280),
        ],
        enabled: true,
      );

      final result = ShrimpPricingValidator.validatePricingTiers(
          invalidConfig.pricingTiers);
      expect(result, isNotNull, reason: 'Wrong order should fail');
      expect(result, contains('descending order'),
          reason: 'Should catch count order first');
    });

    test('Same price should fail order rule', () {
      final invalidConfig = ShrimpPricingConfig(
        pricingTiers: [
          const ShrimpPricing(count: 100, price: 270),
          const ShrimpPricing(count: 90, price: 270), // Same price
          const ShrimpPricing(count: 80, price: 300),
        ],
        enabled: true,
      );

      final result = ShrimpPricingValidator.validatePricingTiers(
          invalidConfig.pricingTiers);
      expect(result, isNotNull, reason: 'Same price should fail order rule');
      expect(result, contains('Price must increase'),
          reason: 'Should mention price increase requirement');
    });

    test('Default config should pass order rule', () {
      final defaultConfig = ShrimpPricingConfig.defaultConfig();

      final result = ShrimpPricingValidator.validatePricingTiers(
          defaultConfig.pricingTiers);
      expect(result, isNull, reason: 'Default config should pass order rule');

      // Verify the order is correct
      final tiers = defaultConfig.pricingTiers;
      for (int i = 0; i < tiers.length - 1; i++) {
        expect(tiers[i].count, greaterThan(tiers[i + 1].count),
            reason:
                'Count should decrease: ${tiers[i].count} > ${tiers[i + 1].count}');
        expect(tiers[i].price, lessThan(tiers[i + 1].price),
            reason:
                'Price should increase: ${tiers[i].price} < ${tiers[i + 1].price}');
      }
    });
  });
}

/// Manual Test Cases for Edge Function Validation:
/// 
/// Test these via admin panel or direct Edge Function calls:
/// 
/// VALID CASES:
/// - Normal pricing (100:270, 90:280, 80:300) -> SUCCESS
/// - Empty price fields -> SUCCESS (skipped)
/// - Valid price ranges (100-10000) -> SUCCESS
/// - Correct order (Count: 100->90->80, Price: 270->280->300) -> SUCCESS
/// 
/// INVALID CASES:
/// - Price = 10 -> FAIL (below minimum)
/// - Price = 5000 -> FAIL (above maximum)  
/// - Price = "abc" -> FAIL (invalid format)
/// - Duplicate count values -> FAIL
/// - Invalid count (95) -> FAIL
/// - Empty pricing list -> FAIL
/// - Negative prices -> FAIL
/// 
/// ORDER RULE FAILURES:
/// - Wrong count order (100:270, 110:280, 80:300) -> FAIL
/// - Wrong price order (100:270, 90:260, 80:300) -> FAIL
/// - Same price (100:270, 90:270, 80:300) -> FAIL
/// - Count not descending (80:300, 100:270, 90:280) -> FAIL
/// 
/// Expected responses:
/// - Valid: { success: true, message: "Config updated successfully" }
/// - Invalid: { success: false, message: "Validation error", error: "Specific error" }
/// 
/// ORDER RULE ERROR MESSAGES:
/// - "Counts must be in descending order (100 -> 90 -> 80)"
/// - "Price must increase as count decreases (Count: 100 -> 90, Price: 270 -> 260)"
