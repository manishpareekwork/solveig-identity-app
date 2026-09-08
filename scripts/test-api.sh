#!/usr/bin/env bash
# Smoke-test deployed Identity API. Reads optional secrets.json (gitignored).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${SOLVEIG_API_BASE:-https://solveig-identity-api-dev.onrender.com}"
TENANT="${SOLVEIG_TENANT:-demo-tenant}"
SECRETS="$ROOT/secrets.json"

echo "== Health =="
HEALTH=$(curl -sS "$BASE/health")
echo "$HEALTH"
echo "$HEALTH" | grep -q '"status":"ok"' || { echo "Health check failed"; exit 1; }

if [[ ! -f "$SECRETS" ]]; then
  echo ""
  echo "No secrets.json — health-only pass. Copy secrets.json.example and add IDENTITY_ADMIN_TOKEN for full test."
  exit 0
fi

read -r IDENTITY_ADMIN_TOKEN SOLVEIG_CLIENT_ID SOLVEIG_CLIENT_KEY SOLVEIG_CLIENT_SECRET < <(
  python3 - "$SECRETS" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(
  d.get("IDENTITY_ADMIN_TOKEN", ""),
  d.get("SOLVEIG_CLIENT_ID", ""),
  d.get("SOLVEIG_CLIENT_KEY", ""),
  d.get("SOLVEIG_CLIENT_SECRET", ""),
)
PY
)

TENANT_UUID=""

is_usable() {
  local v
  v=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  [[ -n "$1" && "$v" != "optional" && "$v" != "optional-if-already-registered" && "$v" != "paste-from-render-dashboard" ]]
}

CID="$SOLVEIG_CLIENT_ID"
CKEY="$SOLVEIG_CLIENT_KEY"
CSEC="$SOLVEIG_CLIENT_SECRET"

if ! is_usable "$CID" && is_usable "$IDENTITY_ADMIN_TOKEN"; then
  echo ""
  echo "== Register client =="
  REG=$(curl -sS -X POST "$BASE/v1/clients" \
    -H "Authorization: Bearer $IDENTITY_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -H "X-Tenant-Id: $TENANT_UUID" \
    -H "X-Correlation-Id: smoke-$(date +%s)" \
    -d "{\"tenant_slug\":\"$TENANT\",\"tenant_display_name\":\"Demo Tenant\",\"display_name\":\"Smoke Test Mobile\",\"allowed_scopes\":[\"identities:read\",\"identities:write\",\"sessions:read\",\"sessions:write\",\"consents:write\",\"qr:issue\",\"qr:resolve\"]}")
  CID=$(echo "$REG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))")
  CKEY=$(echo "$REG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('client_key',''))")
  CSEC=$(echo "$REG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('client_secret',''))")
  TENANT_UUID=$(echo "$REG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tenant_id',''))")
  [[ -n "$CID" ]] || { echo "Register failed: $REG"; exit 1; }
  echo "client_id=$CID"
fi

is_usable "$CID" && is_usable "$CKEY" && is_usable "$CSEC" || {
  echo "Need valid client credentials or IDENTITY_ADMIN_TOKEN in secrets.json"
  exit 1
}

echo ""
echo "== Issue token =="
TOK=$(curl -sS -X POST "$BASE/v1/clients/$CID/tokens" \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Id: $TENANT_UUID" \
  -H "X-Correlation-Id: smoke-token-$(date +%s)" \
  -d "{\"client_key\":\"$CKEY\",\"client_secret\":\"$CSEC\"}")
TOKEN=$(echo "$TOK" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")
[[ -n "$TOKEN" ]] || { echo "Token failed: $TOK"; exit 1; }
if [[ -z "$TENANT_UUID" ]]; then
  TENANT_UUID=$(python3 - <<'PY' "$TOKEN"
import base64, json, sys
p = sys.argv[1].split('.')[1]
p += '=' * (-len(p) % 4)
print(json.loads(base64.urlsafe_b64decode(p)).get('tid', ''))
PY
)
fi
echo "token issued (tenant=$TENANT_UUID)"

echo ""
echo "== Create identity =="
ID=$(curl -sS -X POST "$BASE/v1/identities" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Id: $TENANT_UUID" \
  -H "X-Correlation-Id: smoke-id-$(date +%s)" \
  -H "Idempotency-Key: smoke-$(uuidgen 2>/dev/null || date +%s)" \
  -d '{}')
echo "$ID" | python3 -c "import sys,json; d=json.load(sys.stdin); print('identity_id', d.get('id','ERR'))"
echo "$ID" | grep -q '"id"' || { echo "Create identity failed"; exit 1; }

echo ""
echo "API smoke test passed."
