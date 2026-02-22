# msh

Vanilla OpenClaw gateway deployed on Railway. No web setup wizard — all
configuration lives in this repo and is applied via redeploy or SSH.

## Architecture

```
repo (openclaw.json)  ──push──>  Railway build  ──>  Gateway (port 8080)
                                                      │
                    railway ssh  ───────────────────>  │  (onboard / debug)
                                                      │
                                              /data volume (persistent state)
```

## Initial setup

```bash
# 1. Deploy (already linked via `railway link`)
railway up

# 2. SSH in and run the onboarding wizard
railway ssh
openclaw onboard

# 3. Export the config back to the repo
cat $OPENCLAW_STATE_DIR/openclaw.json
# paste into openclaw.json, commit, push
```

## Day-to-day

Edit `openclaw.json`, push, and Railway redeploys automatically (or `railway up`
for manual deploy). The entrypoint syncs the repo config to the state directory.

For quick changes without a redeploy:

```bash
railway ssh
openclaw config set agents.defaults.model.primary "anthropic/claude-sonnet-4-5"
```

## Environment variables (set in Railway, not in repo)

| Variable | Required | Description |
|---|---|---|
| `OPENCLAW_GATEWAY_TOKEN` | yes | Auth token for the gateway |
| `OPENCLAW_STATE_DIR` | yes | `/data/.openclaw` |
| `OPENCLAW_WORKSPACE_DIR` | yes | `/data/workspace` |
| `ANTHROPIC_API_KEY` | depends | Anthropic API key |
| `OPENAI_API_KEY` | depends | OpenAI API key |

## Useful commands

```bash
railway ssh                       # shell into the container
railway logs                      # view gateway logs
railway logs --build              # view build logs
railway variable set KEY=VALUE    # set env var
railway open                      # open Railway dashboard
```
