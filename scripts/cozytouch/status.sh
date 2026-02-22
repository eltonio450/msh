#!/usr/bin/env bash
# Cozytouch — Get status of all devices
# Usage: ./status.sh [--json]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/cozytouch.sh"

JSON_OUTPUT=false
[ "${1:-}" = "--json" ] && JSON_OUTPUT=true

cozy_login

setup=$(cozy_get "setup")

# Build a place OID → name mapping from the recursive rootPlace structure
places_map=$(echo "$setup" | jq '[.rootPlace | recurse(.subPlaces[]?) | {key: .oid, value: .label}] | from_entries')

if $JSON_OUTPUT; then
  echo "$setup" | jq --argjson places "$places_map" '
    {
      gateways: [.gateways[] | {id: .gatewayId, alive: .alive, version: .connectivity.protocolVersion}],
      heaters: [.devices[] |
        select(.widget == "AtlanticElectricalHeaterWithAdjustableTemperatureSetpoint") |
        {
          url: .deviceURL,
          place: ($places[.placeOID] // "unknown"),
          mode: (.states[] | select(.name == "core:OperatingModeState") | .value),
          on: (.states[] | select(.name == "core:OnOffState") | .value),
          target_temp: (.states[] | select(.name == "core:TargetTemperatureState") | .value),
          comfort_temp: (.states[] | select(.name == "core:ComfortRoomTemperatureState") | .value),
          eco_temp: (.states[] | select(.name == "core:EcoRoomTemperatureState") | .value)
        }
      ],
      temperatures: [.devices[] |
        select(.widget == "TemperatureSensor") |
        {
          url: .deviceURL,
          place: ($places[.placeOID] // "unknown"),
          current_temp: (.states[] | select(.name == "core:TemperatureState") | .value)
        }
      ]
    }'
  exit 0
fi

echo "=== Radiateurs ==="
echo "$setup" | jq -r --argjson places "$places_map" '
  # Build temp sensor lookup: base device ID → temperature
  ([.devices[] | select(.widget == "TemperatureSensor") |
    {key: (.deviceURL | split("#")[0]), value: (.states[] | select(.name == "core:TemperatureState") | .value)}
  ] | from_entries) as $temps |
  .devices[] |
  select(.widget == "AtlanticElectricalHeaterWithAdjustableTemperatureSetpoint") |
  (.deviceURL | split("#")[0]) as $base |
  ($places[.placeOID] // "?") as $place |
  (.states[] | select(.name == "core:OnOffState") | .value) as $on |
  (.states[] | select(.name == "core:OperatingModeState") | .value) as $mode |
  (.states[] | select(.name == "core:TargetTemperatureState") | .value) as $target |
  ($temps[$base] // "N/A") as $current |
  "  \($place): \($current)°C → \($target)°C  [\($mode), \($on)]  \(.deviceURL)"
'

echo ""
echo "=== Gateway ==="
echo "$setup" | jq -r '.gateways[] | "  \(.gatewayId) — alive: \(.alive), version: \(.connectivity.protocolVersion)"'
