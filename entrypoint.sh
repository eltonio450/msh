#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspace}"

mkdir -p "$STATE_DIR"

# --- Git auth (for agent self-edit) ---
if [ -n "${GITHUB_TOKEN:-}" ]; then
  git config --global credential.helper store
  echo "https://x-access-token:${GITHUB_TOKEN}@github.com" > ~/.git-credentials
  chmod 600 ~/.git-credentials
fi

git config --global user.name "msh"
git config --global user.email "msh@openclaw.gateway"

# --- Sync repo → workspace via git clone/pull ---
REPO_URL="https://github.com/eltonio450/msh.git"

if [ -d "$WORKSPACE_DIR/.git" ]; then
  echo "[sync] Pulling latest from repo into workspace"
  cd "$WORKSPACE_DIR"
  git fetch origin main --depth 1
  git reset --hard origin/main
else
  echo "[sync] Cloning repo into workspace"
  git clone --depth 1 "$REPO_URL" "$WORKSPACE_DIR"
fi

# --- Sync gateway config (separate from workspace) ---
cp "$WORKSPACE_DIR/openclaw.json" "$STATE_DIR/openclaw.json"
echo "[sync] openclaw.json → $STATE_DIR/"

# --------------------------------------------------

export PORT="${PORT:-8080}"
export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_WORKSPACE_DIR="$WORKSPACE_DIR"

exec node /openclaw/dist/entry.js gateway --port "$PORT" --bind lan
