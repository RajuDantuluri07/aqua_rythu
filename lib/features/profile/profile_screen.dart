import 'package:flutter/material.dart';
import 'farm_settings_screen.dart';
import 'legal_screen.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../farm/farm_provider.dart';
import '../farm/edit_farm_dialog.dart';
import 'user_provider.dart';
import 'package:aqua_rythu/core/services/farm_service.dart';
import 'package:aqua_rythu/core/services/admin_security_service.dart';
// Admin provider removed temporarily
// import '../admin/admin_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _handleAboutClick() {
    _showAboutDialog();
  }

  void _navigateToAdminAccess() {
    Navigator.of(context).pushNamed(AppRoutes.adminPasscode);
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('About AquaRythu'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AquaRythu - Smart Shrimp Farming'),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('© 2024 AquaRythu Technologies'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAdminPasscodeDialog() {
    final TextEditingController passcodeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Admin Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter admin passcode:'),
            const SizedBox(height: 16),
            TextField(
              controller: passcodeController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                hintText: '4-digit passcode',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final passcode = passcodeController.text.trim();
              Navigator.of(dialogContext).pop();

              if (passcode.isEmpty) return;

              try {
                final adminService = AdminSecurityService();
                final isValid =
                    await adminService.validateAdminAccess(passcode);

                if (mounted) {
                  if (isValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Admin access granted! Session active for 15 minutes.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid passcode'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error occurred'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmProvider);
    final userProfile = ref.watch(userProvider);

    return Scaffold(
      // backgroundColor is now handled by the global theme
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      bottomNavigationBar: const AppBottomBar(currentIndex: 2),
      body: Column(
        children: [
          // 🔹 TOP PROFILE
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(
                        userProfile.profileImageUrl ??
                            "https://i.pravatar.cc/150?img=3",
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  userProfile.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(userProfile.phoneNumber,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 🔹 FARM LIST
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Text(
                  "MY FARMS",
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 10),

                // 🔹 DYNAMIC FARM LIST
                ...farmState.farms.map((farm) {
                  final isActive = farm.id == farmState.selectedId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _farmTile(
                      context,
                      ref,
                      farm: farm,
                      active: isActive,
                    ),
                  );
                }),

                const SizedBox(height: 10),

                // Add Farm Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("+ Add New Farm"),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.addFarm);
                  },
                ),

                const SizedBox(height: 20),

                // GENERAL
                Text(
                  "GENERAL",
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 10),

                _menuTile(Icons.settings, "Account Settings"),
                _menuTile(Icons.notifications, "Notification Preferences"),
                _menuTile(Icons.language, "App Language"),

                // Admin Access - Only show for admin users
                Consumer(
                  builder: (context, ref, child) {
                    // Admin functionality disabled temporarily
                    final isAdmin = false; // ref.watch(isAdminProvider);
                    if (!isAdmin) return const SizedBox.shrink();

                    return _menuTile(
                      Icons.admin_panel_settings,
                      "Admin Control Panel",
                      onTap: _navigateToAdminAccess,
                    );
                  },
                ),

                const SizedBox(height: 20),

                // LEGAL
                Text(
                  "LEGAL & SUPPORT",
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 10),

                _menuTile(Icons.description, "Terms & Conditions", onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LegalScreen.termsAndConditions(),
                      ));
                }),
                _menuTile(Icons.privacy_tip, "Privacy Policy", onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LegalScreen.privacyPolicy(),
                      ));
                }),
                _menuTile(Icons.info, "About AquaRythu",
                    onTap: _handleAboutClick),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // 🔻 LOGOUT
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to log out?'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                        TextButton(
                          child: Text('Logout',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                          onPressed: () async {
                            await ref.read(authProvider.notifier).logout();
                            // Close the dialog first
                            if (!context.mounted) return;
                            Navigator.of(dialogContext).pop();
                            // Navigate to login and remove all previous routes
                            Navigator.pushNamedAndRemoveUntil(
                                context, AppRoutes.login, (route) => false);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text("Logout Account"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.error,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _farmTile(
    BuildContext context,
    WidgetRef ref, {
    required Farm farm,
    required bool active,
  }) {
    final theme = Theme.of(context);
    final status = "${farm.ponds.length} Ponds • ${farm.location}";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FarmSettingsScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primaryContainer.withOpacity(0.3)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.water_drop, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(farm.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    status,
                    style: TextStyle(
                      color: active ? theme.colorScheme.primary : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => EditFarmDialog(
                      farmId: farm.id,
                      initialName: farm.name,
                      initialLocation: farm.location,
                    ),
                  );
                } else if (value == 'delete') {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Delete Farm?'),
                      content: Text(
                        'Are you sure you want to delete "${farm.name}" and all its ponds? This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            try {
                              final farmService = FarmService();
                              await farmService.deleteFarm(farm.id);

                              // Update local state
                              ref
                                  .read(farmProvider.notifier)
                                  .deleteFarm(farm.id);

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      const Text("Farm deleted successfully"),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  backgroundColor: Colors.green.shade600,
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error: $e"),
                                  backgroundColor: Colors.red.shade600,
                                ),
                              );
                            }
                          },
                          child: Text(
                            'Delete',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Edit Farm'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: Color(0xFFE53935)),
                      SizedBox(width: 10),
                      Text(
                        'Delete Farm',
                        style: TextStyle(color: Color(0xFFE53935)),
                      ),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert),
              position: PopupMenuPosition.over,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
