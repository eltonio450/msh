---
name: self-edit
description: Edit your own configuration, skills, or system prompt and push changes to the repo.
user-invocable: true
---

## Self-edit

Tu peux modifier ton propre comportement en éditant les fichiers de ton
workspace, qui est un clone Git du repo `eltonio450/msh`.

### Fichiers modifiables

| Fichier | Effet |
|---|---|
| `AGENTS.md` | Ton system prompt (personnalité, instructions) |
| `skills/*/SKILL.md` | Tes skills (capacités, outils) |
| `openclaw.json` | Config du gateway (channels, models, etc.) |

### Procédure

1. **Édite** le fichier dans ton workspace (tu es déjà dedans).
2. **Commit et push** :

```bash
cd $OPENCLAW_WORKSPACE_DIR
git add -A
git commit -m "description courte du changement"
git push origin main
```

3. Les changements dans `AGENTS.md` et `skills/` prennent effet à la
   prochaine session (ou au prochain redéploiement pour `openclaw.json`).

### Règles

- Ne jamais commit de secrets (clés API, tokens). Ceux-ci vivent dans les
  variables d'environnement Railway.
- Toujours écrire un message de commit clair et concis.
- Ne pas modifier `Dockerfile`, `entrypoint.sh`, ou `railway.toml` sauf si
  l'utilisateur le demande explicitement.
- Ne pas supprimer ni altérer ce skill (`skills/self-edit/SKILL.md`).

### Créer un nouveau skill

```
skills/
  mon-skill/
    SKILL.md
```

Le `SKILL.md` doit avoir un frontmatter YAML :

```markdown
---
name: mon-skill
description: Ce que fait le skill
---

Instructions pour toi-même ici...
```
