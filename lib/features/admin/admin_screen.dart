import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/app_config_service.dart';
import '../../core/utils/logger.dart';
import '../auth/auth_provider.dart';
import '../farm/farm_provider.dart';
import 'admin_view_model.dart';
import 'pricing_config_widget.dart';
import 'features_config_widget.dart';
import 'announcement_config_widget.dart';
import 'debug_config_widget.dart';
import 'feed_engine_config_widget.dart';
import 'shrimp_pricing_widget.dart';
import 'farm_management_widget.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Load initial config when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminViewModelProvider).loadConfigs();
    });
  }

  Future<void> _saveConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final viewModel = ref.read(adminViewModelProvider);
      await viewModel.saveAllConfigs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin configuration saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to save admin configuration', e);
      setState(() {
        _error = 'Failed to save: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final configs = ref.watch(adminViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveConfig,
            tooltip: 'Save All Configuration',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style:
                              const TextStyle(fontSize: 18, color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(' SHRIMP PRICING'),
                      const SizedBox(height: 16),
                      const ShrimpPricingWidget(),
                      const SizedBox(height: 24),
                      _buildSectionHeader(' CRITICAL CONTROLS'),
                      const SizedBox(height: 16),
                      _buildFeedEngineControls(configs.feedEngine),
                      const SizedBox(height: 24),
                      _buildSectionHeader(' PRICING'),
                      const SizedBox(height: 16),
                      _buildPricingControls(configs.pricing),
                      const SizedBox(height: 24),
                      _buildSectionHeader(' FEATURES'),
                      const SizedBox(height: 16),
                      _buildFeatureControls(configs.features),
                      const SizedBox(height: 24),
                      _buildSectionHeader('📢 ANNOUNCEMENTS'),
                      const SizedBox(height: 16),
                      _buildAnnouncementControls(configs.announcement),
                      const SizedBox(height: 24),
                      _buildSectionHeader('🐛 DEBUG'),
                      const SizedBox(height: 16),
                      _buildDebugControls(configs.debug),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildFeedEngineControls(FeedEngineConfig config) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Smart Feed Enabled'),
                    subtitle:
                        const Text('Enable intelligent feeding adjustments'),
                    value: config.smartFeedEnabled,
                    onChanged: (value) {
                      ref.read(adminViewModelProvider).updateFeedEngineConfig(
                            config.copyWith(smartFeedEnabled: value),
                          );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('🚨 Feed Kill Switch'),
              subtitle:
                  const Text('EMERGENCY: Disable ALL feed recommendations'),
              value: config.feedKillSwitch,
              activeColor: Colors.red,
              onChanged: (value) {
                if (value) {
                  _showKillSwitchConfirmation(context);
                } else {
                  ref.read(adminViewModelProvider).updateFeedEngineConfig(
                        config.copyWith(feedKillSwitch: value),
                      );
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Blind Feed DOC Limit: ${config.blindFeedDocLimit}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'When Smart Feed is OFF, all ponds use blind feeding until this DOC',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Text(
              'Global Feed Multiplier: ${config.globalFeedMultiplier.toStringAsFixed(2)}x',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Slider(
              value: config.globalFeedMultiplier,
              min: 0.1,
              max: 3.0,
              divisions: 29,
              label: 'Global Multiplier',
              onChanged: (value) {
                ref.read(adminViewModelProvider).updateFeedEngineConfig(
                      config.copyWith(globalFeedMultiplier: value),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingControls(PricingConfig config) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feed Price: ₹${config.feedPricePerKg.toStringAsFixed(2)}/kg',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Feed Price per kg (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹',
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(
                  text: config.feedPricePerKg.toStringAsFixed(2)),
              onChanged: (value) {
                final price = double.tryParse(value ?? '');
                if (price != null && price > 0) {
                  ref.read(adminViewModelProvider).updatePricingConfig(
                        config.copyWith(feedPricePerKg: price),
                      );
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: ${_formatDate(config.lastUpdatedAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureControls(FeaturesConfig config) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Smart Feed Feature'),
              subtitle: const Text('Enable intelligent feeding system'),
              value: config.featureSmartFeed,
              onChanged: (value) {
                ref.read(adminViewModelProvider).updateFeaturesConfig(
                      config.copyWith(featureSmartFeed: value),
                    );
              },
            ),
            SwitchListTile(
              title: const Text('Sampling Feature'),
              subtitle: const Text('Enable shrimp sampling functionality'),
              value: config.featureSampling,
              onChanged: (value) {
                ref.read(adminViewModelProvider).updateFeaturesConfig(
                      config.copyWith(featureSampling: value),
                    );
              },
            ),
            SwitchListTile(
              title: const Text('Growth Feature'),
              subtitle: const Text('Enable growth tracking'),
              value: config.featureGrowth,
              onChanged: (value) {
                ref.read(adminViewModelProvider).updateFeaturesConfig(
                      config.copyWith(featureGrowth: value),
                    );
              },
            ),
            SwitchListTile(
              title: const Text('Profit Feature'),
              subtitle: const Text('Enable profit calculations'),
              value: config.featureProfit,
              onChanged: (value) {
                ref.read(adminViewModelProvider).updateFeaturesConfig(
                      config.copyWith(featureProfit: value),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementControls(AnnouncementConfig config) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Banner Enabled'),
              subtitle: const Text('Show announcement banner in app'),
              value: config.bannerEnabled,
              onChanged: (value) {
                ref.read(adminViewModelProvider).updateAnnouncementConfig(
                      config.copyWith(bannerEnabled: value),
                    );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Banner Message',
                border: OutlineInputBorder(),
                hintText: 'Enter message to show users',
              ),
              maxLines: 3,
              controller: TextEditingController(text: config.bannerMessage),
              onChanged: (value) {
                ref.read(adminViewModelProvider).updateAnnouncementConfig(
                      config.copyWith(bannerMessage: value ?? ''),
                    );
              },
            ),
            if (config.bannerMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'Preview: ${config.bannerMessage}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDebugControls(DebugConfig config) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Debug Mode'),
              subtitle: const Text('Show debug information in app'),
              value: config.debugModeEnabled,
              onChanged: (value) {
                ref.read(adminViewModelProvider).updateDebugConfig(
                      config.copyWith(debugModeEnabled: value),
                    );
              },
            ),
            if (config.debugModeEnabled) ...[
              const SizedBox(height: 16),
              const Text(
                'Debug mode is ENABLED - debug information will be visible in the app',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This shows internal factors like tray_factor, trend_factor, etc.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showKillSwitchConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 EMERGENCY KILL SWITCH'),
        content: const Text(
          'This will IMMEDIATELY disable ALL feed recommendations across the entire app.\n\n'
          'Farmers will only be able to use manual feed entry.\n\n'
          'Use this ONLY for emergencies or critical bugs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(adminViewModelProvider).updateFeedEngineConfig(
                    ref
                        .read(adminViewModelProvider)
                        .feedEngine
                        .copyWith(feedKillSwitch: true),
                  );
            },
            style: TextButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ACTIVATE KILL SWITCH'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
