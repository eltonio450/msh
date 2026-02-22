---
name: mcz-stove
description: Contrôler un poêle à granulés MCZ via l'API cloud Maestro. Utiliser quand l'utilisateur demande d'allumer, éteindre, régler la température, changer la puissance, ou vérifier l'état du poêle MCZ.
---

# MCZ Stove Control

Contrôle du poêle à granulés MCZ via l'API cloud Maestro (même API que
l'appli officielle). Fonctionne depuis n'importe où, pas besoin d'être sur
le réseau WiFi du poêle. Zéro dépendance externe (Node 18+ fetch natif).

## Prérequis

Variables d'environnement (Railway) :
- `MCZ_USERNAME` – email du compte MCZ
- `MCZ_PASSWORD` – mot de passe du compte MCZ

## Script CLI

Le script `scripts/mcz_cloud.mjs` est le point d'entrée unique.

### Commandes

| Commande | Description |
|---|---|
| `status` | État actuel (température, puissance, modes) |
| `power on` | Allumer le poêle |
| `power off` | Éteindre le poêle |
| `temp <valeur>` | Régler la température cible (ex: `temp 21.5`, range 5-35) |
| `power-level <1-5>` | Régler le niveau de puissance |
| `mode <mode>` | Changer le mode : `manual`, `dynamic`, `comfort`, `overnight`, `power` |
| `fan <0-6>` | Vitesse ventilateur (0-5, 6=auto) |
| `silent on\|off` | Activer/désactiver le mode silencieux |
| `eco on\|off` | Activer/désactiver le mode éco |
| `chrono on\|off` | Activer/désactiver le chronostat |
| `info` | Infos du modèle et commandes disponibles |
| `raw-state` | JSON brut de l'état |
| `raw-status` | JSON brut du statut |

### Exemples d'exécution

```bash
# Voir l'état du poêle
node skills/mcz-stove/scripts/mcz_cloud.mjs status

# Allumer
node skills/mcz-stove/scripts/mcz_cloud.mjs power on

# Régler à 22°C
node skills/mcz-stove/scripts/mcz_cloud.mjs temp 22

# Mode silencieux
node skills/mcz-stove/scripts/mcz_cloud.mjs silent on

# Changer le mode
node skills/mcz-stove/scripts/mcz_cloud.mjs mode dynamic

# Ventilateur en auto
node skills/mcz-stove/scripts/mcz_cloud.mjs fan 6
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
