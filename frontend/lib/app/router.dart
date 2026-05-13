import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/feed/presentation/feed_screen.dart';
import '../features/layers/presentation/layers_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/reports/presentation/tag_submission_screen.dart';
import '../features/trends/presentation/trends_screen.dart';
import 'widgets/main_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/auth',
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/auth'),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
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
        ),
      ],
    ),
  ],
);
