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

if $JSON_OUTPUT; then
  echo "$setup" | jq '{
    gateways: [.gateways[] | {id: .gatewayId, alive: .alive, version: .connectivity.protocolVersion}],
    devices: [.devices[] | {
      url: .deviceURL,
      label: .label,
      widget: .widget,
      available: .available,
      states: [.states[] | {name: .name, value: .value}]
    }]
  }'
  exit 0
fi

echo "=== Gateways ==="
echo "$setup" | jq -r '.gateways[] | "  \(.gatewayId) — alive: \(.alive), version: \(.connectivity.protocolVersion)"'

echo ""
echo "=== Devices ==="
echo "$setup" | jq -r '.devices[] | select(.widget != "TemperatureSensor" and .widget != "OccupancySensor" and .widget != "ContactSensor" and .widget != "CumulativeElectricPowerConsumptionSensor") |
  "  [\(.widget)] \(.label // "unnamed")\n    URL: \(.deviceURL)\n    States:"'

echo "$setup" | jq -r '
  .devices[] |
  select(.widget != "TemperatureSensor" and .widget != "OccupancySensor" and .widget != "ContactSensor" and .widget != "CumulativeElectricPowerConsumptionSensor") |
  . as $dev |
  "--- \($dev.label // $dev.deviceURL) (\($dev.widget)) ---",
  (.states[] |
    select(
      .name == "core:TargetTemperatureState" or
      .name == "core:ComfortRoomTemperatureState" or
      .name == "core:EcoRoomTemperatureState" or
      .name == "core:TemperatureState" or
      .name == "core:OnOffState" or
      .name == "core:OperatingModeState" or
      .name == "io:TargetHeatingLevelState" or
      .name == "core:HeatingStatusState" or
      .name == "core:HolidaysModeState"
    ) | "    \(.name): \(.value)"
  ),
  ""
'

echo ""
echo "=== Temperature Sensors ==="
echo "$setup" | jq -r '
  .devices[] | select(.widget == "TemperatureSensor") |
  "  \(.label // .deviceURL): \((.states[] | select(.name == "core:TemperatureState") | .value) // "N/A")°C"
'
