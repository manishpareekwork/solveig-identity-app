import 'package:go_router/go_router.dart';

import '../features/flow/flow_models.dart';
import '../features/flow/flow_screen.dart';
import '../features/flow/home_screen.dart';
import '../features/flow/setup_screen.dart';
import '../features/flow/verification_result_screen.dart';
import '../state/app_state.dart';

GoRouter createRouter(AppState appState) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: appState,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (appState.loading && loc != '/setup') return null;
      if (!appState.configured && loc != '/setup') return '/setup';
      if (appState.configured && loc == '/setup') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/flow', builder: (context, state) => const FlowScreen()),
      GoRoute(path: '/setup', builder: (context, state) => const SetupScreen()),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is VerificationResultArgs) {
            return VerificationResultScreen(args: extra);
          }
          return const FlowScreen();
        },
      ),
    ],
  );
}
