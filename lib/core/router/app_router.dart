import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/password_screens.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/dashboard/presentation/overview_screen.dart';
import '../../features/portfolios/presentation/kantong_detail_screen.dart';
import '../../features/portfolios/presentation/kantong_editor_screen.dart';
import '../../features/portfolios/presentation/kantong_list_screen.dart';
import '../../features/profile/presentation/account_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/setup/presentation/setup_status_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/snapshots/presentation/history_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../supabase/supabase_providers.dart';

const _authPaths = {'/masuk', '/daftar', '/lupa-sandi'};

/// Pure redirect rule, tested on its own.
String? authRedirect({
  required bool configured,
  required bool signedIn,
  required bool recovering,
  required String location,
}) {
  if (!configured) return location == '/setup' ? null : '/setup';
  if (location == '/setup') return '/';
  if (!signedIn) return _authPaths.contains(location) ? null : '/masuk';
  if (recovering) return location == '/sandi-baru' ? null : '/sandi-baru';
  if (_authPaths.contains(location) || location == '/') return '/beranda';
  return null;
}

/// Routes. Web uses Flutter's default hash URLs (HLD D-3), which also keeps
/// Supabase's `?code=` email links intact.
final appRouterProvider = Provider<GoRouter>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  if (configured) {
    ref.listen(authControllerProvider, (_, _) => refresh.value++);
  }

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = configured ? ref.read(authControllerProvider) : null;
      return authRedirect(
        configured: configured,
        signedIn: session != null,
        recovering: session?.recovering ?? false,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/beranda'),
      GoRoute(path: '/setup', builder: (_, _) => const SetupStatusScreen()),
      GoRoute(path: '/masuk', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/daftar', builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: '/lupa-sandi',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/sandi-baru',
        builder: (_, _) => const UpdatePasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/beranda',
                builder: (_, _) => const OverviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/kantong',
                builder: (_, _) => const KantongListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/statistik',
                builder: (_, _) => const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/riwayat',
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
        ],
      ),
      // Child screens cover the navigation (docs/design-system.md 7.1).
      GoRoute(
        path: '/kantong/baru',
        builder: (_, _) => const KantongEditorScreen(),
      ),
      GoRoute(
        path: '/kantong/:id',
        builder: (_, s) =>
            KantongDetailScreen(kantongId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/kantong/:id/ubah',
        builder: (_, s) =>
            KantongEditorScreen(kantongId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/profil', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/profil/akun', builder: (_, _) => const AccountScreen()),
      GoRoute(path: '/perhatian', builder: (_, _) => const AttentionScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
