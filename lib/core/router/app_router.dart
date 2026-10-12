import 'package:go_router/go_router.dart';

import '../../features/setup/presentation/setup_status_screen.dart';

/// Routes grow per slice. Web uses Flutter's default hash URLs (HLD D-3).
final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SetupStatusScreen()),
  ],
);
