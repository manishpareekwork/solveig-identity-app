import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/auth_storage.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = AuthStorage();
  final appState = AppState(storage);
  await appState.bootstrap();
  runApp(SolveigIdentityApp(appState: appState));
}

class SolveigIdentityApp extends StatelessWidget {
  const SolveigIdentityApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp.router(
        title: 'Solveig Identity',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4D89)),
          useMaterial3: true,
        ),
        routerConfig: createRouter(appState),
      ),
    );
  }
}
