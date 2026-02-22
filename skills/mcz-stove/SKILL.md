---
name: mcz-stove
description: Contrôler un poêle à granulés MCZ via l'API cloud Maestro. Utiliser quand l'utilisateur demande d'allumer, éteindre, régler la température, changer la puissance, ou vérifier l'état du poêle MCZ.
---

# MCZ Stove Control

Contrôle du poêle à granulés MCZ via l'API cloud Maestro (même API que
l'appli officielle). Fonctionne depuis n'importe où, pas besoin d'être sur
le réseau WiFi du poêle.

## Prérequis

Variables d'environnement (Railway) :
- `MCZ_USERNAME` – email du compte MCZ
- `MCZ_PASSWORD` – mot de passe du compte MCZ

Dépendance : `aiohttp` (voir `scripts/requirements.txt`).

Installer si nécessaire :
```bash
pip install -r skills/mcz-stove/scripts/requirements.txt
```

## Script CLI

Le script `scripts/mcz_cloud.py` est le point d'entrée unique.

### Commandes

| Commande | Description |
|---|---|
| `status` | État actuel (température, puissance, modes) |
| `power on` | Allumer le poêle |
| `power off` | Éteindre le poêle |
| `temp <valeur>` | Régler la température cible (ex: `temp 21.5`) |
| `power-level <1-5>` | Régler le niveau de puissance |
| `silent on\|off` | Activer/désactiver le mode silencieux |
| `eco on\|off` | Activer/désactiver le mode éco |
| `chrono on\|off` | Activer/désactiver le chronostat |
| `info` | Infos du modèle et commandes disponibles |
| `raw-state` | JSON brut de l'état |
| `raw-status` | JSON brut du statut |

### Exemples d'exécution

```bash
# Voir l'état du poêle
python skills/mcz-stove/scripts/mcz_cloud.py status

# Allumer
python skills/mcz-stove/scripts/mcz_cloud.py power on

# Régler à 22°C
python skills/mcz-stove/scripts/mcz_cloud.py temp 22

# Mode silencieux
python skills/mcz-stove/scripts/mcz_cloud.py silent on
```

## Workflow

1. **Lire l'état** avant toute action : toujours exécuter `status` d'abord.
2. **Envoyer la commande** demandée par l'utilisateur.
3. **Confirmer** en relisant le statut après quelques secondes.
4. **Reporter** le résultat à l'utilisateur en langage naturel.

## Sécurité

- Ne jamais afficher les credentials MCZ.
- En cas d'erreur d'authentification, demander à l'utilisateur de vérifier
  ses credentials dans les variables d'environnement Railway.
- Ne pas allumer le poêle sans confirmation explicite de l'utilisateur.

## Dépannage

Si `info` ne trouve pas un capteur attendu, c'est que le modèle de poêle
ne le supporte pas. Utiliser `raw-state` et `raw-status` pour explorer
les données brutes et adapter.

## Approche alternative : WebSocket local

Pour un contrôle local (sans passer par le cloud MCZ), le poêle expose un
WebSocket sur `192.168.120.1:81`. Cela nécessite un appareil (ex: Raspberry Pi)
connecté au WiFi du poêle. Voir le projet
[maestrogateway](https://github.com/Chibald/maestrogateway) pour cette approche.
