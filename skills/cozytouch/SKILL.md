---
name: cozytouch
description: Contrôler le chauffage Thermor/Atlantic via l'API Cozytouch (température, modes, état).
user-invocable: true
---

## Cozytouch — Contrôle du chauffage

Tu peux contrôler les équipements Thermor/Atlantic connectés via Cozytouch
(radiateurs, poêles, chauffe-eau) grâce aux scripts dans `scripts/cozytouch/`.

### Prérequis

Les variables d'environnement suivantes doivent être définies (secrets Railway) :

| Variable | Description |
|---|---|
| `COZYTOUCH_USERNAME` | Email du compte Cozytouch |
| `COZYTOUCH_PASSWORD` | Mot de passe du compte Cozytouch |

`jq` doit être installé sur le système (ajouter au Dockerfile si nécessaire).

### Scripts disponibles

Tous les scripts sont dans `$OPENCLAW_WORKSPACE_DIR/scripts/cozytouch/`.

#### 1. État des équipements

```bash
bash scripts/cozytouch/status.sh          # Affichage lisible
bash scripts/cozytouch/status.sh --json   # Sortie JSON structurée
```

Retourne : gateways, appareils avec leurs états (température cible, mode,
niveau de chauffe, etc.), capteurs de température.

#### 2. Régler la température

```bash
# Température cible directe
bash scripts/cozytouch/set-temp.sh <device_url> <temperature>

# Température confort
bash scripts/cozytouch/set-temp.sh --comfort <device_url> <temperature>

# Température éco
bash scripts/cozytouch/set-temp.sh --eco <device_url> <temperature>
```

#### 3. Changer le mode de chauffage

Pour les radiateurs avec température réglable (`AtlanticElectricalHeaterWithAdjustableTemperatureSetpoint`) :

```bash
bash scripts/cozytouch/set-mode.sh <device_url> <mode>
```

Modes : `standby`, `basic`, `internal`, `auto`, `frostprotection`, `normal`, `max`, `prog`, `program`

Pour les radiateurs fil pilote (`AtlanticElectricalHeater`) :

```bash
bash scripts/cozytouch/set-mode.sh --level <device_url> <level>
```

Niveaux : `off`, `eco`, `boost`, `comfort`, `comfort-1`, `comfort-2`, `frostprotection`, `secured`

Mode absence :

```bash
bash scripts/cozytouch/set-mode.sh --away-on <device_url>
bash scripts/cozytouch/set-mode.sh --away-off <device_url>
```

### Workflow type

1. **Commence toujours par `status.sh`** pour découvrir les device URLs et
   l'état actuel avant toute action.
2. Utilise les device URLs retournées pour cibler les commandes.
3. Après une commande, relance `status.sh` pour vérifier que le changement
   a pris effet.

### Types d'appareils

| Widget | Description |
|---|---|
| `AtlanticElectricalHeaterWithAdjustableTemperatureSetpoint` | Radiateur avec consigne de température |
| `AtlanticElectricalHeater` | Radiateur fil pilote (niveaux : eco/comfort/off…) |
| `DomesticHotWaterProduction` | Chauffe-eau |
| `Pod` | Bridge Cozytouch |

### Exemples de demandes utilisateur

| Demande | Action |
|---|---|
| "Mets le chauffage à 21°C" | `status.sh` → identifier le device → `set-temp.sh <url> 21` |
| "Éteins le chauffage" | `set-mode.sh <url> standby` ou `set-mode.sh --level <url> off` |
| "Mets en mode éco" | `set-mode.sh --level <url> eco` ou régler la temp éco |
| "Quel est l'état du chauffage ?" | `status.sh` |
| "Monte un peu la température" | `status.sh` → lire temp actuelle → `set-temp.sh <url> <current+1>` |
| "Je pars en vacances" | `set-mode.sh --away-on <url>` |

### Notes

- Les commandes sont envoyées au cloud Cozytouch (API Overkiz). Elles
  mettent quelques secondes à être appliquées aux appareils.
- En cas d'erreur 401, les scripts re-tentent la connexion automatiquement.
- Ne jamais stocker les identifiants Cozytouch dans le repo — uniquement
  en variables d'environnement Railway.
