# msh

Vanilla OpenClaw gateway deployed on Railway. **Le repo est la source de vérité** :
chaque push synchronise la config, le system prompt et les skills vers l'instance.
Aucune interface web de configuration — tout passe par Git ou SSH.

## Structure

| Fichier | Rôle | Synchro vers |
|---|---|---|
| `openclaw.json` | Config gateway | `$STATE_DIR/openclaw.json` |
| `AGENTS.md` | System prompt de l'agent | `$WORKSPACE_DIR/AGENTS.md` |
| `skills/` | Skills custom (priorité max) | `$WORKSPACE_DIR/skills/` |
| `Dockerfile` | Build de l'instance | — |
| `entrypoint.sh` | Sync repo → instance au boot | — |
| `railway.toml` | Config Railway | — |

## Workflow

```bash
# Modifier le comportement → éditer, push, redeploy
vim AGENTS.md            # changer la personnalité
vim skills/mon-skill/SKILL.md  # ajouter un skill
git add -A && git commit -m "..." && git push
railway up               # ou auto-deploy via GitHub

# Debug / onboarding → SSH
railway ssh
openclaw doctor
openclaw channels status
```

## Env vars (Railway, pas dans le repo)

| Variable | Description |
|---|---|
| `OPENCLAW_GATEWAY_TOKEN` | Auth token gateway |
| `OPENCLAW_STATE_DIR` | `/data/.openclaw` |
| `OPENCLAW_WORKSPACE_DIR` | `/data/workspace` |
| `WHATSAPP_ALLOW_FROM` | Numéro WhatsApp autorisé |
| `ANTHROPIC_API_KEY` | Clé API Anthropic |
