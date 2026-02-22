# msh

OpenClaw instance configuration, deployed on [Railway](https://railway.com).

## Deployment

The OpenClaw gateway runs on Railway via the official template.

- **Control UI**: https://openclaw-production-794c.up.railway.app/openclaw
- **Setup Wizard**: https://openclaw-production-794c.up.railway.app/setup

## Configuration

- `openclaw.json` — main OpenClaw gateway configuration
- `AGENTS.md` — agent system prompt and personality

## Useful commands

```bash
# Check Railway status
railway status

# View logs
railway logs

# Set a variable
railway variable set KEY=VALUE

# Open Railway dashboard
railway open
```
