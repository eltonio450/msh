#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspace}"

mkdir -p "$STATE_DIR" "$WORKSPACE_DIR"

# Sync config from repo to state dir (repo is source of truth).
# Skip if the repo config is the minimal placeholder and a richer one already exists.
if [ -f /app/openclaw.json ]; then
  repo_size=$(wc -c < /app/openclaw.json)
  existing_size=0
  [ -f "$STATE_DIR/openclaw.json" ] && existing_size=$(wc -c < "$STATE_DIR/openclaw.json")

  if [ "$repo_size" -gt 100 ] || [ "$existing_size" -eq 0 ]; then
    cp /app/openclaw.json "$STATE_DIR/openclaw.json"
    echo "[entrypoint] Config synced from repo to $STATE_DIR/openclaw.json"
  else
    echo "[entrypoint] Keeping existing config ($existing_size bytes) over repo placeholder ($repo_size bytes)"
  fi
fi

PORT="${PORT:-8080}"

exec openclaw gateway start \
  --bind lan \
  --port "$PORT" \
  --allow-unconfigured
