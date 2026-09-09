import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/defaults.dart';
import '../../state/app_state.dart';
import '../../utils/view_insets.dart';
import '../../widgets/identity_loading.dart';

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
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final state = context.read<AppState>();
    _baseUrl.text = state.baseUrl;
    _tenant.text = state.tenantSlug;
    _clientId.text = state.clientId;
    _clientKey.text = state.clientKey;
    _clientSecret.text = state.clientSecret;
    _adminToken.text = state.adminToken;
    _initialized = true;
  }

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
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: ListView(
        padding: screenPadding(context, horizontal: 16),
        children: [
          if (state.loading)
            const IdentityLoadingPanel(message: 'Connecting to in-house API…', height: 180)
          else ...[
            Text(
              state.configured ? 'API connection' : 'Connect to API',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Update the in-house identity API endpoint or client credentials. '
              'Changes are saved on this device after Connect.',
            ),
          ],
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
            child: Text(state.loading ? 'Connecting…' : 'Save & connect'),
          ),
          if (state.configured) ...[
            const SizedBox(height: 12),
            Text(
              'Connected · ${state.registeredProfileCount} registered profile${state.registeredProfileCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
