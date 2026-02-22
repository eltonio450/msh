#!/usr/bin/env bash
# Cozytouch API — shared functions
# Requires: curl, jq
# Env vars: COZYTOUCH_USERNAME, COZYTOUCH_PASSWORD

set -euo pipefail

COZYTOUCH_API="https://ha110-1.overkiz.com/enduser-mobile-web/enduserAPI"
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
  local http_code
  http_code=$(curl -s -o /dev/null -w '%{http_code}' \
    -c "$COOKIE_JAR" \
    -X POST "$COZYTOUCH_API/login" \
    -H "User-Agent: $COZYTOUCH_UA" \
    -d "userId=${COZYTOUCH_USERNAME}&userPassword=${COZYTOUCH_PASSWORD}")

  if [ "$http_code" != "200" ]; then
    echo "ERROR: Login failed (HTTP $http_code)" >&2
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
  # remaining args are JSON command objects: {"name":"cmd","parameters":[...]}
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
