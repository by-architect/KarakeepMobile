import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/viewmodels/session_controller.dart';
import '../../features/bookmarks/presentation/screens/bookmarks_home_screen.dart';

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
}

/// Session-driven routing: signed-out users land on login, signed-in users
/// never see it. Screens don't navigate after sign-in/out themselves.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final at = state.matchedLocation;
      if (session.isLoading) return at == Routes.splash ? null : Routes.splash;

      final signedIn = session.value != null;
      if (!signedIn) return at == Routes.login ? null : Routes.login;
      if (at == Routes.login || at == Routes.splash) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const _Splash()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.home, builder: (_, _) => const BookmarksHomeScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold();
}
