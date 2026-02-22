#!/usr/bin/env bash
# Cozytouch API — shared functions
# Auth flow: Atlantic OAuth → JWT → Overkiz session
# Requires: curl, jq
# Env vars: COZYTOUCH_USERNAME, COZYTOUCH_PASSWORD

set -euo pipefail

COZYTOUCH_API="https://ha110-1.overkiz.com/enduser-mobile-web/enduserAPI"
ATLANTIC_API="https://apis.groupe-atlantic.com"
ATLANTIC_CLIENT_ID="Q3RfMUpWeVRtSUxYOEllZkE3YVVOQmpGblpVYToyRWNORHpfZHkzNDJVSnFvMlo3cFNKTnZVdjBh"
COZYTOUCH_UA="msh-agent/1.0"
COOKIE_JAR="${TMPDIR:-/tmp}/cozytouch_cookies_$$"

cleanup() { rm -f "$COOKIE_JAR"; }
trap cleanup EXIT

_require_env() {
  if [ -z "${COZYTOUCH_USERNAME:-}" ] || [ -z "${COZYTOUCH_PASSWORD:-}" ]; then
    echo "ERROR: COZYTOUCH_USERNAME and COZYTOUCH_PASSWORD must be set" >&2
    exit 1
  fi
}

cozy_login() {
  _require_env

  # Step 1: Get OAuth access token from Atlantic Group API
  local token_response
  token_response=$(curl -s -X POST "$ATLANTIC_API/token" \
    -H "Authorization: Basic $ATLANTIC_CLIENT_ID" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&username=GA-PRIVATEPERSON/${COZYTOUCH_USERNAME}&password=${COZYTOUCH_PASSWORD}")

  local access_token
  access_token=$(echo "$token_response" | jq -r '.access_token // empty')
  if [ -z "$access_token" ]; then
    echo "ERROR: Atlantic OAuth failed: $token_response" >&2
    exit 1
  fi

  # Step 2: Exchange access token for Overkiz JWT
  local jwt
  jwt=$(curl -s "$ATLANTIC_API/magellan/accounts/jwt" \
    -H "Authorization: Bearer $access_token")
  jwt=$(echo "$jwt" | tr -d '"')
  if [ -z "$jwt" ]; then
    echo "ERROR: Failed to get JWT token" >&2
    exit 1
  fi

  # Step 3: Login to Overkiz with JWT
  local http_code
  http_code=$(curl -s -o /dev/null -w '%{http_code}' \
    -c "$COOKIE_JAR" \
    -X POST "$COZYTOUCH_API/login" \
    -H "User-Agent: $COZYTOUCH_UA" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "jwt=$jwt")

  if [ "$http_code" != "200" ]; then
    echo "ERROR: Overkiz login failed (HTTP $http_code)" >&2
    exit 1
  fi
}

cozy_get() {
  local endpoint="$1"
  curl -s -b "$COOKIE_JAR" \
    -H "User-Agent: $COZYTOUCH_UA" \
    "$COZYTOUCH_API/$endpoint"
}

cozy_post() {
  local endpoint="$1"
  local body="$2"
  curl -s -b "$COOKIE_JAR" \
    -X POST "$COZYTOUCH_API/$endpoint" \
    -H "User-Agent: $COZYTOUCH_UA" \
    -H "Content-Type: application/json" \
    -d "$body"
}

cozy_send_command() {
  local device_url="$1"
  local label="$2"
  shift 2
  local cmds=""
  for c in "$@"; do
    [ -n "$cmds" ] && cmds="$cmds,"
    cmds="$cmds$c"
  done

  local payload
  payload=$(cat <<ENDJSON
{
  "label": "$label",
  "actions": [
    {
      "deviceURL": "$device_url",
      "commands": [$cmds]
    }
  ]
}
ENDJSON
)
  cozy_post "exec/apply" "$payload"
}

cmd_json() {
  local name="$1"
  shift
  if [ $# -eq 0 ]; then
    printf '{"name":"%s"}' "$name"
  else
    local params=""
    for p in "$@"; do
      [ -n "$params" ] && params="$params,"
      params="$params$p"
    done
    printf '{"name":"%s","parameters":[%s]}' "$name" "$params"
  fi
}
