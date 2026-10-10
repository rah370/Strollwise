import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/app_providers.dart';

class MainShell extends ConsumerWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  static const _tabs = [
    '/explore',
    '/add-tag',
    '/feed',
    '/trends',
    '/profile',
  ];

  int _currentIndex(String location) {
    final index = _tabs.indexWhere((route) => location.startsWith(route));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final hideNavigation = location.startsWith('/add-tag');
    final submittedBanner = ref.watch(tagSubmittedBannerProvider);
    return Scaffold(
      body: Column(
        children: [
          if (submittedBanner != null)
            Material(
              color: const Color(0xFF166534),
              elevation: 2,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Tag submitted',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dismiss',
                        onPressed: () {
                          ref.read(tagSubmittedBannerProvider.notifier).state =
                              null;
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: hideNavigation
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex(location),
              onDestinationSelected: (index) => context.go(_tabs[index]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.hexagon_outlined),
                  label: 'Explore',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_location_alt_outlined),
                  label: 'Add Tag',
                ),
                NavigationDestination(
                  icon: Icon(Icons.dynamic_feed_outlined),
                  label: 'Feed',
                ),
                NavigationDestination(
                  icon: Icon(Icons.trending_up_outlined),
                  label: 'Trends',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }
}
