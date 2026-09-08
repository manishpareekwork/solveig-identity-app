import 'package:go_router/go_router.dart';

import '../features/flow/flow_screen.dart';
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
      GoRoute(path: '/', builder: (context, state) => const FlowScreen()),
      GoRoute(path: '/setup', builder: (context, state) => const SetupScreen()),
    ],
  );
}
