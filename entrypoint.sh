#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspace}"

mkdir -p "$STATE_DIR" "$WORKSPACE_DIR"

# --- Git auth (for agent self-edit) ---
if [ -n "${GITHUB_TOKEN:-}" ]; then
  git config --global credential.helper store
  echo "https://x-access-token:${GITHUB_TOKEN}@github.com" > ~/.git-credentials
  chmod 600 ~/.git-credentials
fi
git config --global user.name "msh"
git config --global user.email "msh@openclaw.gateway"

# --- Copy repo files to workspace ---
cp /app/openclaw.json "$STATE_DIR/openclaw.json"
cp /app/AGENTS.md "$WORKSPACE_DIR/AGENTS.md"
cp -r /app/skills/. "$WORKSPACE_DIR/skills/" 2>/dev/null || true

# --- Init git in workspace if not already ---
if [ ! -d "$WORKSPACE_DIR/.git" ]; then
  cd "$WORKSPACE_DIR"
  git init
  git remote add origin "https://github.com/eltonio450/msh.git"
fi

echo "[entrypoint] ready"

export PORT="${PORT:-8080}"
export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_WORKSPACE_DIR="$WORKSPACE_DIR"

exec node /openclaw/dist/entry.js gateway --port "$PORT" --bind lan
