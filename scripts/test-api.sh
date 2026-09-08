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

eval "$(python3 <<'PY'
import json, pathlib, shlex
p = pathlib.Path("'"$SECRETS"'")
d = json.loads(p.read_text())
for k in ("IDENTITY_ADMIN_TOKEN", "SOLVEIG_CLIENT_ID", "SOLVEIG_CLIENT_KEY", "SOLVEIG_CLIENT_SECRET"):
    v = d.get(k, "")
    print(f"export {k}={shlex.quote(v)}")
PY
)"

CID="${SOLVEIG_CLIENT_ID:-}"
CKEY="${SOLVEIG_CLIENT_KEY:-}"
CSEC="${SOLVEIG_CLIENT_SECRET:-}"

if [[ -z "$CID" && -n "${IDENTITY_ADMIN_TOKEN:-}" ]]; then
  echo ""
  echo "== Register client =="
  REG=$(curl -sS -X POST "$BASE/v1/clients" \
    -H "Authorization: Bearer $IDENTITY_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -H "X-Tenant-Id: $TENANT" \
    -H "X-Correlation-Id: smoke-$(date +%s)" \
    -d "{\"tenant_slug\":\"$TENANT\",\"tenant_display_name\":\"Demo Tenant\",\"display_name\":\"Smoke Test Mobile\",\"allowed_scopes\":[\"identities:read\",\"identities:write\",\"sessions:read\",\"sessions:write\",\"consents:write\",\"qr:issue\",\"qr:resolve\"]}")
  CID=$(echo "$REG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))")
  CKEY=$(echo "$REG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('client_key',''))")
  CSEC=$(echo "$REG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('client_secret',''))")
  [[ -n "$CID" ]] || { echo "Register failed: $REG"; exit 1; }
  echo "client_id=$CID"
fi

[[ -n "$CID" && -n "$CKEY" && -n "$CSEC" ]] || { echo "Need client credentials or IDENTITY_ADMIN_TOKEN in secrets.json"; exit 1; }

echo ""
echo "== Issue token =="
TOK=$(curl -sS -X POST "$BASE/v1/clients/$CID/tokens" \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Id: $TENANT" \
  -H "X-Correlation-Id: smoke-token-$(date +%s)" \
  -d "{\"client_key\":\"$CKEY\",\"client_secret\":\"$CSEC\"}")
TOKEN=$(echo "$TOK" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")
[[ -n "$TOKEN" ]] || { echo "Token failed: $TOK"; exit 1; }
echo "token issued"

echo ""
echo "== Create identity =="
ID=$(curl -sS -X POST "$BASE/v1/identities" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "X-Tenant-Id: $TENANT" \
  -H "X-Correlation-Id: smoke-id-$(date +%s)" \
  -H "Idempotency-Key: smoke-$(uuidgen 2>/dev/null || date +%s)" \
  -d '{}')
echo "$ID" | python3 -c "import sys,json; d=json.load(sys.stdin); print('identity_id', d.get('id','ERR'))"
echo "$ID" | grep -q '"id"' || { echo "Create identity failed"; exit 1; }

echo ""
echo "API smoke test passed."
