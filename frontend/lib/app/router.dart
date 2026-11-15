/// App routes and auth gate.
///
/// Unauthenticated users can only reach /auth, forgot-password, and legal
/// pages. A restored JWT sends them to /explore. Shell tabs match the
/// thesis features: Explore (map), Add Tag, Feed, Trends, Profile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/feed/presentation/feed_screen.dart';
import '../features/layers/presentation/layers_screen.dart';
import '../features/legal/presentation/legal_screens.dart';
import '../features/profile/presentation/achievements_screen.dart';
import '../features/profile/presentation/my_tags_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import '../features/profile/presentation/visit_history_screen.dart';
import '../features/profile/profile_copy.dart';
import '../features/reports/presentation/tag_submission_screen.dart';
import '../features/trends/presentation/trends_screen.dart';
import '../shared/providers/app_providers.dart';
import 'widgets/main_shell.dart';

bool _isShellLocation(String loc) {
  const shell = {'/explore', '/feed', '/add-tag', '/layers'};
  return shell.contains(loc) ||
      loc.startsWith('/profile') ||
      loc.startsWith('/trends');
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/auth',
  refreshListenable: routerRefreshListenable,
  redirect: (BuildContext context, GoRouterState state) {
    final container = ProviderScope.containerOf(context);
    if (!container.read(authBootstrapCompleteProvider)) {
      return null;
    }
    final token = container.read(authTokenProvider);
    final loc = state.matchedLocation;
    final loggedIn = token != null && token.isNotEmpty;
    final onAuth = loc == '/auth' || loc == '/auth/forgot';
    final onLegal = loc == '/privacy' || loc == '/terms';
    if (!loggedIn && _isShellLocation(loc)) {
      return '/auth';
    }
    if (loggedIn && onAuth) {
      return '/explore';
    }
    if (onLegal) {
      return null;
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/auth'),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(
      path: '/auth/forgot',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) => const TermsOfUseScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/explore',
          builder: (context, state) => const ExploreScreen(),
        ),
        GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
        GoRoute(
          path: '/add-tag',
          builder: (context, state) => const TagSubmissionScreen(),
        ),
        GoRoute(
          path: '/layers',
          builder: (context, state) => const LayersScreen(),
        ),
        GoRoute(
          path: '/trends',
          builder: (context, state) => TrendsScreen(
            zoneId: state.uri.queryParameters['zoneId'],
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
          routes: [
            GoRoute(
              path: 'tags',
              builder: (context, state) => MyTagsScreen(
                initialFilter: tagFilterFromQuery(
                  state.uri.queryParameters['status'],
                ),
              ),
            ),
            GoRoute(
              path: 'achievements',
              builder: (context, state) => const AchievementsScreen(),
            ),
            GoRoute(
              path: 'visits',
              builder: (context, state) => const VisitHistoryScreen(),
            ),
            GoRoute(
              path: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
