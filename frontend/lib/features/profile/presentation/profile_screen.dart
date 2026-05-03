import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/theme/colors.dart';
import '../../../shared/models/report.dart';
import '../../../shared/providers/app_providers.dart';

enum _PrivacyMode { public, anonymous, private }

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _displayName = 'New Explorer';
  String _city = 'Set your city';
  _PrivacyMode _privacyMode = _PrivacyMode.public;
  final Set<String> _savedZones = {'Food Zones', 'Local Picks'};

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authUserEmailProvider);
    final displayName = _displayName == 'New Explorer'
        ? _displayNameFromEmail(email)
        : _displayName;

    final feed = ref
        .watch(feedProvider)
        .maybeWhen(data: (items) => items, orElse: () => const <ReportModel>[]);
    final taggedCount = feed.length;
    final approvedCount = ((taggedCount * 0.72).round()).clamp(0, taggedCount);
    final helpfulVotes = taggedCount * 2 + 6;
    final progress = (approvedCount / 25).clamp(0.0, 1.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F6FB), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              const _TopBar(),
              const SizedBox(height: 12),
              _ProfileHeaderCard(
                displayName: displayName,
                city: _city,
                onEdit: _editProfile,
              ),
              const SizedBox(height: 10),
              _StatsRow(
                taggedCount: taggedCount,
                approvedCount: approvedCount,
                helpfulVotes: helpfulVotes,
              ),
              const SizedBox(height: 10),
              _ProgressCard(progress: progress, approvedCount: approvedCount),
              const SizedBox(height: 10),
              _SectionShell(
                title: 'Location Preference',
                child: _LocationPreferenceCard(
                  onSetManual: _setManualLocationFromProfile,
                ),
              ),
              const SizedBox(height: 10),
              const _SectionShell(
                title: 'Badges',
                trailing: 'View all',
                child: _BadgesWrap(),
              ),
              const SizedBox(height: 10),
              _SectionShell(
                title: 'Recent Contributions',
                child: _RecentContributionsList(
                  contributions: feed.take(3).toList(),
                ),
              ),
              const SizedBox(height: 10),
              _SectionShell(
                title: 'Privacy & Visibility',
                child: _PrivacySection(
                  mode: _privacyMode,
                  onModeChanged: (mode) => setState(() => _privacyMode = mode),
                ),
              ),
              const SizedBox(height: 10),
              _SectionShell(
                title: 'Saved Zones',
                trailing: 'View all',
                child: _SavedZonesWrap(
                  selected: _savedZones,
                  onToggle: (value) {
                    setState(() {
                      if (_savedZones.contains(value)) {
                        _savedZones.remove(value);
                      } else {
                        _savedZones.add(value);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    final result = await showDialog<({String name, String city})>(
      context: context,
      builder: (_) =>
          _EditProfileDialog(initialName: _displayName, initialCity: _city),
    );
    if (result == null) return;
    setState(() {
      _displayName = result.name.trim().isEmpty
          ? 'New Explorer'
          : result.name.trim();
      _city = result.city.trim().isEmpty ? 'Set your city' : result.city.trim();
    });
  }

  Future<void> _setManualLocationFromProfile() async {
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final result = await showDialog<LatLng>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set manual location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Latitude'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lngController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Longitude'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(latController.text.trim());
              final lng = double.tryParse(lngController.text.trim());
              if (lat == null ||
                  lng == null ||
                  lat.abs() > 90 ||
                  lng.abs() > 180) {
                return;
              }
              Navigator.of(context).pop(LatLng(lat, lng));
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    latController.dispose();
    lngController.dispose();

    if (result == null) return;
    ref.read(currentUserLocationProvider.notifier).state = result;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Manual location saved: ${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}',
          ),
        ),
      );
    }
  }

  String _displayNameFromEmail(String? email) {
    if (email == null || email.isEmpty || email == 'demo@strollwise.local') {
      return 'New Explorer';
    }
    return email.split('@').first.replaceAll('.', ' ');
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.initialName,
    required this.initialCity,
  });

  final String initialName;
  final String initialCity;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _cityController = TextEditingController(text: widget.initialCity);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop((name: _nameController.text, city: _cityController.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.menu_rounded, color: AppColors.primaryText, size: 28),
        Expanded(
          child: Center(
            child: Text(
              'Profile',
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Icon(Icons.settings_outlined, color: AppColors.primaryText, size: 26),
      ],
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.displayName,
    required this.city,
    required this.onEdit,
  });

  final String displayName;
  final String city;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.mapInk.withValues(alpha: 0.14),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.mapInk,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF60A5FA),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F8EF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'New Contributor',
                    style: TextStyle(
                      color: Color(0xFF2F855A),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.mutedText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      city,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: AppColors.mutedText),
            tooltip: 'Edit profile',
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.taggedCount,
    required this.approvedCount,
    required this.helpfulVotes,
  });

  final int taggedCount;
  final int approvedCount;
  final int helpfulVotes;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            value: '$taggedCount',
            label: 'Zones Tagged',
            icon: Icons.location_on_outlined,
            accent: const Color(0xFF54B685),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            value: '$approvedCount',
            label: 'Approved Tags',
            icon: Icons.verified_outlined,
            accent: const Color(0xFF60A5FA),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            value: '$helpfulVotes',
            label: 'Helpful Votes',
            icon: Icons.thumb_up_alt_outlined,
            accent: const Color(0xFFF6B73C),
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress, required this.approvedCount});

  final double progress;
  final int approvedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Community Mapper',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$approvedCount approved tags / 25 needed for next badge',
            style: const TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.secondaryAction,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationPreferenceCard extends StatelessWidget {
  const _LocationPreferenceCard({required this.onSetManual});

  final VoidCallback onSetManual;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Set a manual location anytime if GPS is off or inaccurate.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onSetManual,
          icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
          label: const Text('Change'),
        ),
      ],
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (trailing != null)
                Row(
                  children: [
                    Text(
                      trailing!,
                      style: const TextStyle(
                        color: Color(0xFF2F855A),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFF2F855A),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BadgesWrap extends StatelessWidget {
  const _BadgesWrap();

  @override
  Widget build(BuildContext context) {
    const badges = [
      (
        'Zone Scout',
        Color(0xFFE9F8EF),
        Color(0xFF2F855A),
        Icons.place_outlined,
      ),
      (
        'Food Finder',
        Color(0xFFFFF4E5),
        Color(0xFFB7791F),
        Icons.restaurant_rounded,
      ),
      (
        'Transport Helper',
        Color(0xFFF2EEFF),
        Color(0xFF6B46C1),
        Icons.directions_bus_outlined,
      ),
      (
        'Local Guide',
        Color(0xFFEEF5FF),
        Color(0xFF3B82F6),
        Icons.star_border_rounded,
      ),
      (
        'Safety Reporter',
        Color(0xFFFFF0F6),
        Color(0xFFB83280),
        Icons.shield_outlined,
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges
          .map(
            (badge) => _TagChip(
              label: badge.$1,
              background: badge.$2,
              foreground: badge.$3,
              icon: badge.$4,
            ),
          )
          .toList(),
    );
  }
}

class _RecentContributionsList extends StatelessWidget {
  const _RecentContributionsList({required this.contributions});

  final List<ReportModel> contributions;

  @override
  Widget build(BuildContext context) {
    if (contributions.isEmpty) {
      return const Text(
        'No contributions yet. Add your first zone tag from the Add Tag tab.',
        style: TextStyle(
          color: AppColors.mutedText,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < contributions.length; i++) ...[
          _ContributionRow(report: contributions[i]),
          if (i < contributions.length - 1)
            const Divider(height: 16, color: AppColors.border),
        ],
      ],
    );
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({required this.report});

  final ReportModel report;

  @override
  Widget build(BuildContext context) {
    final approved = report.id % 3 != 0;
    final statusColor = approved
        ? const Color(0xFF2F855A)
        : const Color(0xFFB7791F);
    final title = report.tags.isNotEmpty
        ? report.tags.take(2).join(' • ')
        : report.category.toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: statusColor.withValues(alpha: 0.14),
          child: Icon(
            _iconForCategory(report.category),
            size: 17,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${report.category}  ·  ${report.h3Index.substring(0, 7)}',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            approved ? 'Approved' : 'Pending validation',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
      ],
    );
  }

  IconData _iconForCategory(String category) {
    final key = category.toLowerCase();
    if (key.contains('food')) return Icons.restaurant_rounded;
    if (key.contains('transport')) return Icons.directions_bus_outlined;
    if (key.contains('safety')) return Icons.shield_outlined;
    if (key.contains('crowd')) return Icons.groups_rounded;
    return Icons.pin_drop_outlined;
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.mode, required this.onModeChanged});

  final _PrivacyMode mode;
  final ValueChanged<_PrivacyMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PrivacyChip(
                label: 'Public',
                icon: Icons.public_rounded,
                selected: mode == _PrivacyMode.public,
                onTap: () => onModeChanged(_PrivacyMode.public),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PrivacyChip(
                label: 'Anonymous',
                icon: Icons.visibility_off_outlined,
                selected: mode == _PrivacyMode.anonymous,
                onTap: () => onModeChanged(_PrivacyMode.anonymous),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PrivacyChip(
                label: 'Private',
                icon: Icons.lock_outline_rounded,
                selected: mode == _PrivacyMode.private,
                onTap: () => onModeChanged(_PrivacyMode.private),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Your exact location is never shown. Tags are grouped into zones.',
          style: TextStyle(
            color: AppColors.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PrivacyChip extends StatelessWidget {
  const _PrivacyChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? const Color(0xFF2F855A) : AppColors.mutedText;
    final background = selected
        ? const Color(0xFFE8F7EF)
        : const Color(0xFFF8FAFC);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF8AC7A5) : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedZonesWrap extends StatelessWidget {
  const _SavedZonesWrap({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('Food Zones', Icons.restaurant_rounded),
      ('Transport', Icons.directions_bus_outlined),
      ('Local Picks', Icons.star_border_rounded),
      ('Nature', Icons.park_outlined),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (entry) => FilterChip(
              selected: selected.contains(entry.$1),
              onSelected: (_) => onToggle(entry.$1),
              avatar: Icon(entry.$2, size: 16),
              label: Text(entry.$1),
            ),
          )
          .toList(),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: AppColors.border),
    boxShadow: const [
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );
}
