import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/defaults.dart';
import '../../state/app_state.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _baseUrl = TextEditingController(text: kDefaultApiBaseUrl);
  final _tenant = TextEditingController(text: kDefaultTenantSlug);
  final _adminToken = TextEditingController();
  final _clientId = TextEditingController();
  final _clientKey = TextEditingController();
  final _clientSecret = TextEditingController();

  @override
  void dispose() {
    _baseUrl.dispose();
    _tenant.dispose();
    _adminToken.dispose();
    _clientId.dispose();
    _clientKey.dispose();
    _clientSecret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('API Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text('Connecting to API…'),
          ] else
            const Text(
              'Connect to Solveig Identity API. Provide the admin token to auto-register '
              'a mobile client, or paste existing client credentials.',
            ),
          const SizedBox(height: 16),
          TextField(controller: _baseUrl, decoration: const InputDecoration(labelText: 'API base URL')),
          TextField(controller: _tenant, decoration: const InputDecoration(labelText: 'Tenant slug')),
          TextField(
            controller: _adminToken,
            decoration: const InputDecoration(labelText: 'Admin token (IDENTITY_ADMIN_TOKEN)'),
            obscureText: true,
          ),
          const Divider(height: 32),
          TextField(
            controller: _clientId,
            decoration: const InputDecoration(labelText: 'Existing client ID (optional)'),
          ),
          TextField(
            controller: _clientKey,
            decoration: const InputDecoration(labelText: 'Client key (optional)'),
          ),
          TextField(
            controller: _clientSecret,
            decoration: const InputDecoration(labelText: 'Client secret (optional)'),
            obscureText: true,
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: state.loading
                ? null
                : () => state.connect(
                      baseUrl: _baseUrl.text,
                      tenantSlug: _tenant.text,
                      adminToken: _adminToken.text,
                      existingClientId: _clientId.text.isEmpty ? null : _clientId.text,
                      existingClientKey: _clientKey.text.isEmpty ? null : _clientKey.text,
                      existingClientSecret:
                          _clientSecret.text.isEmpty ? null : _clientSecret.text,
                    ),
            child: state.loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
