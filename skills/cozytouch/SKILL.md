---
name: cozytouch
description: Contrôler le chauffage Thermor/Atlantic via l'API Cozytouch (température, modes, état).
user-invocable: true
---

## Cozytouch — Contrôle du chauffage

Tu peux contrôler les radiateurs Thermor/Atlantic connectés via Cozytouch
grâce aux scripts dans `scripts/cozytouch/`.

### Prérequis

Les variables d'environnement suivantes doivent être définies (secrets Railway) :

| Variable | Description |
|---|---|
| `COZYTOUCH_USERNAME` | Email du compte Cozytouch |
| `COZYTOUCH_PASSWORD` | Mot de passe du compte Cozytouch |

### Scripts disponibles

Tous les scripts sont dans `$OPENCLAW_WORKSPACE_DIR/scripts/cozytouch/`.

#### 1. État des équipements

```bash
bash scripts/cozytouch/status.sh          # Affichage lisible
bash scripts/cozytouch/status.sh --json   # Sortie JSON structurée
```

Affiche pour chaque radiateur : la pièce, la température mesurée, la
température cible, le mode de fonctionnement, et le device URL.

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

```bash
bash scripts/cozytouch/set-mode.sh <device_url> <mode>
```

Modes : `standby` (éteint), `basic` (manuel), `internal`, `auto`, `prog`

Mode absence :

```bash
bash scripts/cozytouch/set-mode.sh --away-on <device_url>
bash scripts/cozytouch/set-mode.sh --away-off <device_url>
```

### Installation connue

7 radiateurs `AtlanticElectricalHeaterWithAdjustableTemperatureSetpoint` :

| Pièce | Device URL |
|---|---|
| Entree | `io://2050-6790-7020/10444457#1` |
| Kitchen | `io://2050-6790-7020/11637364#1` |
| Kitchen (2e) | `io://2050-6790-7020/3993420#1` |
| Chambre du bas | `io://2050-6790-7020/13081373#1` |
| Living room (1) | `io://2050-6790-7020/16002095#1` |
| Living room (2) | `io://2050-6790-7020/6978063#1` |
| Kitchen - escalier | `io://2050-6790-7020/6857447#1` |

### Workflow type

1. **Commence toujours par `status.sh`** pour voir l'état actuel avant
   toute action.
2. Utilise les device URLs pour cibler les commandes.
3. Après une commande, relance `status.sh` pour confirmer le changement.
4. Si l'utilisateur demande de changer "le chauffage" sans préciser la
   pièce, demande-lui quelle pièce ou applique à tous.

### Exemples de demandes utilisateur

| Demande | Action |
|---|---|
| "Mets le chauffage à 21°C" | Demander la pièce, ou appliquer à tous |
| "Mets le salon à 20" | `set-temp.sh io://2050-6790-7020/16002095#1 20` + `set-temp.sh io://2050-6790-7020/6978063#1 20` |
| "Éteins le chauffage" | `set-mode.sh <url> standby` pour chaque radiateur |
| "État du chauffage ?" | `status.sh` |
| "Monte un peu la temp du salon" | `status.sh` → lire temp cible → +1°C |
| "Je pars en vacances" | `set-mode.sh --away-on <url>` pour chaque |

### Notes

- Les commandes sont envoyées au cloud Cozytouch (API Overkiz). Elles
  mettent quelques secondes à être appliquées aux appareils.
- L'authentification passe par OAuth Atlantic Group → JWT → session Overkiz.
- Ne jamais stocker les identifiants dans le repo.
