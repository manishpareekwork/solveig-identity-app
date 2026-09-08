/// Default development API target (Render).
const kDefaultApiBaseUrl = 'https://solveig-identity-api-dev.onrender.com';

const kDefaultTenantSlug = 'demo-tenant';

/// Optional compile-time secrets (`flutter run --dart-define-from-file=secrets.json`).
const kDevAdminToken = String.fromEnvironment('IDENTITY_ADMIN_TOKEN');
const kDevClientId = String.fromEnvironment('SOLVEIG_CLIENT_ID');
const kDevClientKey = String.fromEnvironment('SOLVEIG_CLIENT_KEY');
const kDevClientSecret = String.fromEnvironment('SOLVEIG_CLIENT_SECRET');

const kRequiredScopes = [
  'identities:read',
  'identities:write',
  'sessions:read',
  'sessions:write',
  'consents:write',
  'qr:issue',
  'qr:resolve',
];
