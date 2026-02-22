#!/usr/bin/env bash
# Cozytouch — Set target temperature on a heater
# Usage: ./set-temp.sh <device_url> <temperature>
# Usage: ./set-temp.sh --comfort <device_url> <temperature>
# Usage: ./set-temp.sh --eco <device_url> <temperature>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/cozytouch.sh"

MODE="target"
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --comfort) MODE="comfort"; shift ;;
    --eco)     MODE="eco";     shift ;;
    *)         echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ $# -lt 2 ]; then
  echo "Usage: $0 [--comfort|--eco] <device_url> <temperature>" >&2
  exit 1
fi

DEVICE_URL="$1"
TEMPERATURE="$2"

cozy_login

case "$MODE" in
  comfort)
    echo "Setting comfort temperature to ${TEMPERATURE}°C on $DEVICE_URL"
    cozy_send_command "$DEVICE_URL" "Set comfort temperature" \
      "$(cmd_json "setComfortTemperature" "$TEMPERATURE")" \
      "$(cmd_json "refreshSetpointLoweringTemperatureInProgMode")" \
      "$(cmd_json "refreshTargetTemperature")"
    ;;
  eco)
    echo "Setting eco temperature to ${TEMPERATURE}°C on $DEVICE_URL"
    cozy_send_command "$DEVICE_URL" "Set eco temperature" \
      "$(cmd_json "setEcoTemperature" "$TEMPERATURE")" \
      "$(cmd_json "refreshSetpointLoweringTemperatureInProgMode")"
    ;;
  target)
    echo "Setting target temperature to ${TEMPERATURE}°C on $DEVICE_URL"
    cozy_send_command "$DEVICE_URL" "Set target temperature" \
      "$(cmd_json "setTargetTemperature" "$TEMPERATURE")" \
      "$(cmd_json "refreshEcoTemperature")" \
      "$(cmd_json "refreshComfortTemperature")" \
      "$(cmd_json "refreshSetpointLoweringTemperatureInProgMode")"
    ;;
esac

echo "Done."
