#!/bin/bash
set -euo pipefail

# Entrypoint to prepare auth and start the Hytale server
# Behavior:
# - If HYTALE_AUTOMATE_DEVICE_FLOW=1, request a device code, print verification link/code,
#   poll token endpoint, fetch profiles, create a game session, and export tokens.
# - Persist tokens to /opt/hytale/server/oauth_tokens.json and session tokens to /opt/hytale/server/session_tokens.json
# - Finally attempt to start a server binary from the mounted /opt/hytale/server directory.

DEFAULT_CLIENT_ID="hytale-server"
CLIENT_ID="${HYTALE_CLIENT_ID:-$DEFAULT_CLIENT_ID}"
SCOPE="${HYTALE_SCOPE:-openid offline auth:server}"
SERVER_DIR="/opt/hytale/server"

log() { echo "[entrypoint] $*"; }

if [ "${HYTALE_AUTOMATE_DEVICE_FLOW:-0}" = "1" ]; then
  log "Starting device code flow (METHOD B) to obtain OAuth tokens..."

  resp=$(curl -s -X POST "https://oauth.accounts.hytale.com/oauth2/device/auth" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${CLIENT_ID}" \
    -d "scope=${SCOPE}")

  device_code=$(echo "$resp" | jq -r .device_code)
  user_code=$(echo "$resp" | jq -r .user_code)
  verification_uri=$(echo "$resp" | jq -r .verification_uri)
  verification_uri_complete=$(echo "$resp" | jq -r .verification_uri_complete)
  interval=$(echo "$resp" | jq -r .interval // 5)

  if [ -z "$device_code" ] || [ "$device_code" = "null" ]; then
    echo "Failed to request device code: $resp"
    exit 1
  fi

  cat <<-EOF

Device authorization required.
Open the following URL in a browser and complete authorization:

  ${verification_uri_complete}

If you cannot open the direct link, visit:

  ${verification_uri}
  and enter code: ${user_code}

Waiting for authorization (this container will poll the token endpoint)...

EOF

  # Poll for token
  while true; do
    token_resp=$(curl -s -X POST "https://oauth.accounts.hytale.com/oauth2/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=${CLIENT_ID}" \
      -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
      -d "device_code=${device_code}")

    if echo "$token_resp" | jq -e '.error' >/dev/null 2>&1; then
      err=$(echo "$token_resp" | jq -r .error)
      if [ "$err" = "authorization_pending" ]; then
        sleep $interval
        continue
      else
        echo "Device flow error: $token_resp"
        exit 1
      fi
    else
      access_token=$(echo "$token_resp" | jq -r .access_token)
      refresh_token=$(echo "$token_resp" | jq -r .refresh_token)
      expires_in=$(echo "$token_resp" | jq -r .expires_in)

      mkdir -p "$SERVER_DIR"
      jq -n --arg at "$access_token" --arg rt "$refresh_token" --argjson exp "$expires_in" '{access_token:$at,refresh_token:$rt,expires_in:$exp}' > "$SERVER_DIR/oauth_tokens.json"
      log "OAuth tokens saved to $SERVER_DIR/oauth_tokens.json"
      break
    fi
  done

  # Get profiles
  profiles=$(curl -s -H "Authorization: Bearer $access_token" "https://account-data.hytale.com/my-account/get-profiles")
  owner_uuid=$(echo "$profiles" | jq -r '.profiles[0].uuid')

  if [ -z "$owner_uuid" ] || [ "$owner_uuid" = "null" ]; then
    echo "Failed to fetch profiles: $profiles"
    exit 1
  fi

  log "Creating game session for profile: $owner_uuid"
  session_resp=$(curl -s -X POST "https://sessions.hytale.com/game-session/new" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    -d "{\"uuid\": \"$owner_uuid\"}")

  session_token=$(echo "$session_resp" | jq -r .sessionToken)
  identity_token=$(echo "$session_resp" | jq -r .identityToken)

  if [ -z "$session_token" ] || [ "$session_token" = "null" ]; then
    echo "Failed to create game session: $session_resp"
    exit 1
  fi

  jq -n --arg st "$session_token" --arg it "$identity_token" '{sessionToken:$st,identityToken:$it}' > "$SERVER_DIR/session_tokens.json"
  log "Session tokens saved to $SERVER_DIR/session_tokens.json"

  # Export for this process
  export HYTALE_SERVER_SESSION_TOKEN="$session_token"
  export HYTALE_SERVER_IDENTITY_TOKEN="$identity_token"

else
  log "HYTALE_AUTOMATE_DEVICE_FLOW not enabled; skipping device code flow."
fi

# Start server binary from the mounted server directory
cd "$SERVER_DIR" || true

if [ -x "$SERVER_DIR/HytaleServer.aot" ]; then
  log "Starting HytaleServer.aot"
  exec "$SERVER_DIR/HytaleServer.aot"
elif ls "$SERVER_DIR"/*.jar >/dev/null 2>&1; then
  jarfile=$(ls "$SERVER_DIR"/*.jar | head -n1)
  log "Starting Java server $jarfile"
  exec java -jar "$jarfile"
else
  echo "No server binary found in $SERVER_DIR. Place HytaleServer.aot or HytaleServer.jar into the mounted Server directory and restart the container."
  exec /bin/bash
fi
