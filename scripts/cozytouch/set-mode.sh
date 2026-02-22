#!/usr/bin/env bash
# Cozytouch — Set heating mode on a device
#
# For radiators with adjustable temperature (AtlanticElectricalHeaterWithAdjustableTemperatureSetpoint):
#   ./set-mode.sh <device_url> <mode>
#   Modes: standby, basic, internal, auto, frostprotection, normal, max, prog, program
#
# For pilot-wire heaters (AtlanticElectricalHeater):
#   ./set-mode.sh --level <device_url> <level>
#   Levels: off, eco, boost, comfort, comfort-1, comfort-2, frostprotection, secured
#
# Away mode:
#   ./set-mode.sh --away-on <device_url>
#   ./set-mode.sh --away-off <device_url>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/cozytouch.sh"

ACTION="mode"
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --level)     ACTION="level";     shift ;;
    --away-on)   ACTION="away-on";   shift ;;
    --away-off)  ACTION="away-off";  shift ;;
    *)           echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

DEVICE_URL="${1:?Usage: $0 [--level|--away-on|--away-off] <device_url> [value]}"
VALUE="${2:-}"

cozy_login

case "$ACTION" in
  mode)
    [ -z "$VALUE" ] && { echo "Usage: $0 <device_url> <mode>" >&2; exit 1; }
    echo "Setting operating mode to '$VALUE' on $DEVICE_URL"
    cozy_send_command "$DEVICE_URL" "Change operating mode" \
      "$(cmd_json "setOperatingMode" "\"$VALUE\"")" \
      "$(cmd_json "refreshOperatingMode")"
    ;;
  level)
    [ -z "$VALUE" ] && { echo "Usage: $0 --level <device_url> <level>" >&2; exit 1; }
    echo "Setting heating level to '$VALUE' on $DEVICE_URL"
    cozy_send_command "$DEVICE_URL" "Change heating level" \
      "$(cmd_json "setHeatingLevel" "\"$VALUE\"")"
    ;;
  away-on)
    echo "Enabling away mode on $DEVICE_URL"
    cozy_send_command "$DEVICE_URL" "Set away mode ON" \
      "$(cmd_json "setHolidays" "\"on\"")"
    ;;
  away-off)
    echo "Disabling away mode on $DEVICE_URL"
    cozy_send_command "$DEVICE_URL" "Set away mode OFF" \
      "$(cmd_json "setHolidays" "\"off\"")"
    ;;
esac

echo "Done."
