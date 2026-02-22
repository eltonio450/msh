#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspace}"

mkdir -p "$STATE_DIR" "$WORKSPACE_DIR"

# --- Sync repo → instance (repo is source of truth) ---

# Gateway config
if [ -f /app/openclaw.json ]; then
  cp /app/openclaw.json "$STATE_DIR/openclaw.json"
  echo "[sync] openclaw.json → $STATE_DIR/"
fi

# Agent system prompt
if [ -f /app/AGENTS.md ]; then
  cp /app/AGENTS.md "$WORKSPACE_DIR/AGENTS.md"
  echo "[sync] AGENTS.md → $WORKSPACE_DIR/"
fi

# Skills (workspace skills have highest precedence in OpenClaw)
if [ -d /app/skills ]; then
  mkdir -p "$WORKSPACE_DIR/skills"
  cp -r /app/skills/. "$WORKSPACE_DIR/skills/"
  echo "[sync] skills/ → $WORKSPACE_DIR/skills/"
fi

# --------------------------------------------------

export PORT="${PORT:-8080}"
export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_WORKSPACE_DIR="$WORKSPACE_DIR"

exec node /openclaw/dist/entry.js gateway --port "$PORT" --bind lan
