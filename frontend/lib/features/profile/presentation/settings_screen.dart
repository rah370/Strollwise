import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../profile_copy.dart';
import 'profile_actions.dart';
import 'profile_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authUserEmailProvider);
    final token = ref.watch(authTokenProvider);
    final isDemo = isLocalDemoSession(token);
    final userMe = ref.watch(userMeProvider);
    final user = userMe.maybeWhen(data: (u) => u, orElse: () => null);
    final mapLocation = ref.watch(currentUserLocationProvider);
    final locationLabel = exploreLocationLabel(
      lat: mapLocation?.latitude ?? user?.manualMapLat,
      lng: mapLocation?.longitude ?? user?.manualMapLng,
    );
    final displayName = userMe.maybeWhen(
      data: (u) =>
          (u?.displayName != null && u!.displayName!.trim().isNotEmpty)
          ? u.displayName!.trim()
          : displayNameFromEmail(u?.email ?? email),
      orElse: () => displayNameFromEmail(email),
    );

    return ProfileSubpageScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const ProfileSectionHeader(title: 'Account'),
          const SizedBox(height: 8),
          ProfilePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isDemo ? 'Demo session' : (email ?? user?.email ?? ''),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: () => editProfile(context, ref),
                    child: const Text('Edit profile'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const ProfileSectionHeader(title: 'Map location'),
          const SizedBox(height: 8),
          ExploreLocationRow(
            cityLabel: locationLabel,
            onChange: () => setManualLocationFromProfile(context, ref),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use a chosen Cebu place when you do not want Explore to follow live GPS.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          const ProfileSectionHeader(title: 'Privacy'),
          const SizedBox(height: 8),
          const ProfilePanel(
            child: Text(
              kProfilePrivacyCopy,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ProfilePanel(
            padding: EdgeInsets.zero,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      'Privacy policy',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/privacy'),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  ListTile(
                    title: const Text(
                      'Terms of use',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/terms'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!isDemo)
            FilledButton.tonalIcon(
              onPressed: () => showLogoutConfirm(context, ref),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
              style: FilledButton.styleFrom(
                foregroundColor: AppColors.alert,
                backgroundColor: AppColors.safetyFill,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
        ],
      ),
    );
  }
}
