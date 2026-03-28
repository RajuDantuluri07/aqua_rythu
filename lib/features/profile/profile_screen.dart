import 'package:flutter/material.dart';
import 'farm_settings_screen.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../farm/farm_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmState = ref.watch(farmProvider);

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
                    const CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(
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
                  "Rajesh Kumar",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text("+91 98765 43210",
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
                      title: farm.name,
                      status: "${farm.ponds.length} Ponds • ${farm.location}",
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

                const SizedBox(height: 20),

                // LEGAL
                Text(
                  "LEGAL & SUPPORT",
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 10),

                _menuTile(Icons.description, "Terms & Conditions"),
                _menuTile(Icons.privacy_tip, "Privacy Policy"),
                _menuTile(Icons.info, "About AquaRythu"),

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
                          onPressed: () {
                            ref.read(authProvider.notifier).logout();
                            // Close the dialog first
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
    BuildContext context, {
    required String title,
    required String status,
    required bool active,
  }) {
    final theme = Theme.of(context);
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
                  Text(title,
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
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}
