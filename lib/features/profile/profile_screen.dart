import 'package:flutter/material.dart';
import 'legal_screen.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../farm/farm_provider.dart';
import '../farm/farms_list_sheet.dart';
import 'user_provider.dart';
import '../upgrade/upgrade_to_pro_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _primaryGreen = Color(0xFF1B8A4C);
  static const _lightGrey = Color(0xFFF2F4F6);
  static const _sectionLabelColor = Color(0xFF9E9E9E);
  static const _cardBorder = Color(0xFFE8ECF0);

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmProvider);
    final userProfile = ref.watch(userProvider);
    final connectedFarms = farmState.farms.length;

    return Scaffold(
      backgroundColor: _lightGrey,
      bottomNavigationBar: const AppBottomBar(currentIndex: 2),
      body: SafeArea(
        child: ListView(
          children: [
            // ── PROFILE HEADER ──────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundImage: NetworkImage(
                          userProfile.profileImageUrl ??
                              'https://i.pravatar.cc/150?img=3',
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: _primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    userProfile.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userProfile.email,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userProfile.phoneNumber,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── PREMIUM ACCESS BANNER ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B8A4C), Color(0xFF25A862)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PREMIUM ACCESS',
                            style: TextStyle(
                              color: Color(0xFFB8F0D0),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Upgrade to PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Unlock advanced farm analytics',
                            style: TextStyle(
                              color: Color(0xFFCCF0DD),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const UpgradeToProScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Upgrade Now',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── STATUS CARD ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const FarmsListSheet(),
                ),
                child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'STATUS',
                            style: TextStyle(
                              color: _sectionLabelColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connected Farms: $connectedFarms',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.water_drop,
                          color: _primaryGreen, size: 22),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right,
                        color: Color(0xFFBBBBBB), size: 18),
                  ],
                ),
              ),
              ),
            ),

            const SizedBox(height: 20),

            // ── SECURITY ─────────────────────────────────────────────────
            _sectionLabel('SECURITY'),
            _sectionCard([
              _menuItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {},
              ),
              _menuItem(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => LegalScreen.privacyPolicy()),
                ),
              ),
              _menuItem(
                icon: Icons.gavel_outlined,
                label: 'Terms and Conditions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => LegalScreen.termsAndConditions()),
                ),
                showDivider: false,
              ),
            ]),

            const SizedBox(height: 16),

            // ── OPTION ───────────────────────────────────────────────────
            _sectionLabel('OPTION'),
            _sectionCard([
              _menuItem(
                icon: Icons.translate_outlined,
                label: 'Language',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'English',
                        style: TextStyle(
                          color: _primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right,
                        color: Color(0xFFBBBBBB), size: 20),
                  ],
                ),
                showDivider: false,
              ),
            ]),

            const SizedBox(height: 16),

            // ── SUPPORT ──────────────────────────────────────────────────
            _sectionLabel('SUPPORT'),
            _sectionCard([
              _menuItem(
                icon: Icons.help_outline_rounded,
                label: 'FAQ',
                onTap: () {},
              ),
              _menuItem(
                icon: Icons.chat_outlined,
                label: 'Aqua Rythu WhatsApp',
                externalLink: true,
                onTap: () => _launchUrl('https://wa.me/918179363691'),
              ),
              _menuItem(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                onTap: () =>
                    _launchUrl('mailto:support@aquarythu.com'),
              ),
              _menuItem(
                icon: Icons.update_rounded,
                label: 'Check Updates',
                onTap: () {},
              ),
              _menuItem(
                icon: Icons.group_outlined,
                label: 'Telegram Group',
                externalLink: true,
                onTap: () => _launchUrl('https://t.me/aquarythu'),
                showDivider: false,
              ),
            ]),

            const SizedBox(height: 16),

            // ── ACCOUNT ──────────────────────────────────────────────────
            _sectionLabel('ACCOUNT'),
            _sectionCard([
              _menuItem(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                labelColor: const Color(0xFFE53935),
                iconColor: const Color(0xFFE53935),
                showDivider: false,
                onTap: () => _showLogoutDialog(context),
              ),
            ]),

            const SizedBox(height: 24),

            // ── FOOTER ───────────────────────────────────────────────────
            const Center(
              child: Text(
                'AQUARYTHU V1.0.0',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: Color(0xFFBBBBBB),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: _sectionLabelColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool showDivider = true,
    bool externalLink = false,
    Color? labelColor,
    Color? iconColor,
    Widget? trailing,
  }) {
    final effectiveIconColor = iconColor ?? const Color(0xFF444444);
    final effectiveLabelColor = labelColor ?? const Color(0xFF1A1A1A);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: effectiveIconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: effectiveLabelColor,
                    ),
                  ),
                ),
                trailing ??
                    Icon(
                      externalLink
                          ? Icons.open_in_new_rounded
                          : Icons.chevron_right,
                      color: const Color(0xFFBBBBBB),
                      size: 20,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
              height: 1, thickness: 1, indent: 66, color: Color(0xFFF0F0F0)),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (!context.mounted) return;
              Navigator.of(dialogContext).pop();
              Navigator.pushNamedAndRemoveUntil(
                  context, AppRoutes.login, (route) => false);
            },
            child: const Text('Sign Out',
                style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }
}
