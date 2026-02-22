#!/usr/bin/env python3
"""
MCZ Maestro Cloud API CLI – controls MCZ pellet stoves via the official cloud.
Uses the same API as the MCZ Maestro mobile app.

Environment variables required:
  MCZ_USERNAME  – MCZ account email
  MCZ_PASSWORD  – MCZ account password

Usage:
  python mcz_cloud.py status          # current stove state
  python mcz_cloud.py power on|off    # turn on / off
  python mcz_cloud.py temp <value>    # set target temperature (°C)
  python mcz_cloud.py power-level <n> # set power level (1-5)
  python mcz_cloud.py silent on|off   # toggle silent mode
  python mcz_cloud.py eco on|off      # toggle eco mode
  python mcz_cloud.py chrono on|off   # toggle chronostat
  python mcz_cloud.py mode <mode>     # set mode (manual|dynamic|comfort|overnight|power)
  python mcz_cloud.py fan <0-6>       # set fan speed (0-5, 6=auto)
  python mcz_cloud.py info            # stove model & available commands
  python mcz_cloud.py raw-state       # full raw state JSON
  python mcz_cloud.py raw-status      # full raw status JSON
"""

import argparse
import asyncio
import json
import os
import sys
from dataclasses import asdict, dataclass

try:
    import aiohttp
except ImportError:
    sys.exit("Missing dependency: pip install aiohttp")

BASE_URL = "https://s.maestro.mcz.it"
LOGIN_URL = f"{BASE_URL}/hlapi/v1.0/Authorization/Login"
STOVES_URL = f"{BASE_URL}/hlapi/v1.0/Nav/FirstVisibleObjectsPaginated"
TENANT_ID = "7c201fd8-42bd-4333-914d-0f5822070757"


@dataclass
class MczProgramCommand:
    SensorId: str | None = None
    Value: object | None = None


class MczCloudClient:
    def __init__(self, username: str, password: str):
        self._username = username
        self._password = password
        self._token: str | None = None
        self._stoves: list[dict] = []

    async def login(self) -> None:
        headers = {"content-type": "application/json", "tenantid": TENANT_ID}
        body = {"username": self._username, "password": self._password}
        async with aiohttp.ClientSession() as session:
            async with session.post(LOGIN_URL, json=body, headers=headers) as resp:
                data = await resp.json()
                if "Token" not in data:
                    raise RuntimeError(f"Login failed: {json.dumps(data, indent=2)}")
                self._token = data["Token"]

    async def _request(self, method: str, url: str, body=None) -> dict | list | None:
        if not self._token:
            await self.login()
        headers = {"auth-token": self._token}
        async with aiohttp.ClientSession() as session:
            if method == "GET":
                async with session.get(url, headers=headers) as resp:
                    if resp.status == 401:
                        await self.login()
                        return await self._request(method, url, body)
                    return await resp.json()
            else:
                headers["content-type"] = "application/json"
                async with session.post(url, headers=headers, json=body) as resp:
                    if resp.status == 401:
                        await self.login()
                        return await self._request(method, url, body)
                    return await resp.json()

    async def get_stoves(self) -> list[dict]:
        raw = await self._request("POST", STOVES_URL, {})
        self._stoves = raw if isinstance(raw, list) else []
        return self._stoves

    def _stove_node(self, idx: int = 0) -> dict:
        return self._stoves[idx]["Node"]

    async def get_state(self, stove_id: str) -> dict:
        return await self._request("GET", f"{BASE_URL}/mcz/v1.0/Appliance/{stove_id}/State")

    async def get_status(self, stove_id: str) -> dict:
        return await self._request("GET", f"{BASE_URL}/mcz/v1.0/Appliance/{stove_id}/Status")

    async def get_model(self, model_id: str) -> dict:
        return await self._request("GET", f"{BASE_URL}/hlapi/v1.0/Model/{model_id}")

    async def ping(self, stove_id: str) -> None:
        await self._request("POST", f"{BASE_URL}/mcz/v1.0/Program/Ping/{stove_id}")

    async def activate_program(
        self, stove_id: str, model_id: str, sensor_set_type_id: str,
        configuration_id: str, sensor_id: str, value: object,
    ) -> dict | None:
        url = f"{BASE_URL}/mcz/v1.0/Program/ActivateProgram/{stove_id}"
        body = {
            "ModelId": model_id,
            "ConfigurationId": configuration_id,
            "SensorSetTypeId": sensor_set_type_id,
            "Commands": [{"SensorId": sensor_id, "Value": value}],
        }
        return await self._request("POST", url, body)


def find_sensor(model: dict, sensor_name: str) -> tuple[str, str] | None:
    """Find a sensor_id and configuration_id by sensor name in the model.
    Tries exact match first, then with m1_/m2_/m3_ prefix."""
    for mc in model.get("ModelConfigurations", []):
        for cfg in mc.get("Configurations", []):
            name = cfg.get("SensorName", "").lower()
            if name == sensor_name.lower():
                return cfg["SensorId"], mc["ConfigurationId"]
    for prefix in ("m1_", "m2_", "m3_"):
        for mc in model.get("ModelConfigurations", []):
            for cfg in mc.get("Configurations", []):
                name = cfg.get("SensorName", "").lower()
                if name == f"{prefix}{sensor_name.lower()}":
                    return cfg["SensorId"], mc["ConfigurationId"]
    return None


def find_sensor_with_mapping(model: dict, sensor_name: str, mapping_key: str) -> tuple[str, str, object] | None:
    """Find sensor and resolve mapping value (e.g. 'on' -> 1, 'off' -> 40)."""
    for prefix in ("", "m1_", "m2_", "m3_"):
        target = f"{prefix}{sensor_name}".lower()
        for mc in model.get("ModelConfigurations", []):
            for cfg in mc.get("Configurations", []):
                name = cfg.get("SensorName", "").lower()
                if name == target and cfg.get("Mappings") and mapping_key in cfg["Mappings"]:
                    return cfg["SensorId"], mc["ConfigurationId"], cfg["Mappings"][mapping_key]
    return None


STOVE_STATES_M1 = {
    0: "Éteint", 1: "Vérification", 2: "Nettoyage (froid)", 3: "Chargement pellets (froid)",
    4: "Démarrage 1 (froid)", 5: "Démarrage 2 (froid)", 6: "Nettoyage (chaud)",
    7: "Chargement pellets (chaud)", 8: "Démarrage 1 (chaud)", 9: "Démarrage 2 (chaud)",
    10: "Stabilisation", 11: "Puissance 1", 12: "Puissance 2", 13: "Puissance 3",
    14: "Puissance 4", 15: "Puissance 5", 30: "Diagnostics", 31: "Allumé",
    40: "Extinction", 41: "Refroidissement", 42: "Nettoyage (bas)", 43: "Nettoyage (haut)",
    44: "Déblocage vis", 45: "Auto Éco", 46: "Veille",
    50: "Erreur: échec allumage", 51: "Erreur: pas de flamme",
    52: "Erreur: surchauffe réservoir", 53: "Erreur: température fumées trop haute",
}

MODE_LABELS = {
    "manual": "Manuel", "dynamic": "Dynamique", "comfort": "Confort",
    "overnight": "Nuit", "power": "Puissance",
}


def format_status(state: dict, status: dict) -> str:
    lines = []

    connected = status.get("IsConnected", state.get("IsConnected"))
    lines.append(f"Connecté : {'Oui' if connected else 'Non'}")

    stato = status.get("stato_stufa")
    if isinstance(stato, int) and stato in STOVE_STATES_M1:
        state_label = STOVE_STATES_M1[stato]
    elif status.get("Status"):
        state_label = status["Status"]
    elif state.get("state"):
        state_label = str(state["state"])
    else:
        state_label = "Inconnu"

    is_on = isinstance(stato, int) and 1 <= stato <= 46 and stato not in (0, 40, 41, 44, 45, 46)
    lines.append(f"Allumé : {'Oui' if is_on else 'Non'}")
    lines.append(f"État : {state_label}")

    mode = status.get("mod_lav_att") or state.get("mod_lav_att")
    if mode:
        lines.append(f"Mode : {MODE_LABELS.get(mode, mode)}")

    temp_amb = status.get("temp_amb_install") or state.get("temp_amb_install")
    if temp_amb is not None:
        lines.append(f"Température ambiante : {temp_amb}°C")

    temp_target = status.get("set_amb1") or state.get("set_amb1")
    if temp_target is not None:
        lines.append(f"Température cible : {temp_target}°C")

    temp_fumi = state.get("temp_fumi")
    if temp_fumi is not None:
        lines.append(f"Température fumées : {temp_fumi}°C")

    potenza = state.get("potenza_att") or status.get("potenza_att")
    if potenza is not None:
        lines.append(f"Niveau de puissance : {potenza}")

    fan = status.get("set_vent_v1")
    if fan is not None:
        lines.append(f"Ventilateur : {fan}")

    eco = status.get("att_eco", state.get("att_eco"))
    if eco is not None:
        lines.append(f"Mode éco : {'Oui' if eco else 'Non'}")

    silent = status.get("silent_enabled")
    if silent is not None:
        lines.append(f"Mode silencieux : {'Oui' if silent else 'Non'}")

    chrono = status.get("crono_enabled", state.get("crono_enabled"))
    if chrono is not None:
        lines.append(f"Chronostat : {'Oui' if chrono else 'Non'}")

    pellet = status.get("sens_liv_pellet", state.get("sens_liv_pellet"))
    if pellet is not None:
        lines.append(f"Capteur pellets : {'OK' if pellet else 'Bas/absent'}")

    if state.get("IsInError") or status.get("IsInError"):
        alarm = state.get("last_alarm", "inconnu")
        lines.append(f"ERREUR : {alarm}")

    manut = status.get("ore_prox_manut")
    if manut is not None:
        lines.append(f"Heures avant maintenance : {manut}h")

    return "\n".join(lines)


async def main():
    parser = argparse.ArgumentParser(description="MCZ Maestro Cloud CLI")
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("status", help="Current stove status")
    sub.add_parser("info", help="Stove model & available commands")
    sub.add_parser("raw-state", help="Full raw state JSON")
    sub.add_parser("raw-status", help="Full raw status JSON")

    p_power = sub.add_parser("power", help="Turn stove on/off")
    p_power.add_argument("value", choices=["on", "off"])

    p_temp = sub.add_parser("temp", help="Set target temperature")
    p_temp.add_argument("value", type=float)

    p_plevel = sub.add_parser("power-level", help="Set power level")
    p_plevel.add_argument("value", type=int, choices=range(1, 6))

    p_silent = sub.add_parser("silent", help="Silent mode on/off")
    p_silent.add_argument("value", choices=["on", "off"])

    p_eco = sub.add_parser("eco", help="Eco mode on/off")
    p_eco.add_argument("value", choices=["on", "off"])

    p_chrono = sub.add_parser("chrono", help="Chronostat on/off")
    p_chrono.add_argument("value", choices=["on", "off"])

    p_mode = sub.add_parser("mode", help="Set operating mode")
    p_mode.add_argument("value", choices=["manual", "dynamic", "comfort", "overnight", "power"])

    p_fan = sub.add_parser("fan", help="Set fan speed (0-5, 6=auto)")
    p_fan.add_argument("value", type=int, choices=range(0, 7))

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    username = os.environ.get("MCZ_USERNAME")
    password = os.environ.get("MCZ_PASSWORD")
    if not username or not password:
        sys.exit("Set MCZ_USERNAME and MCZ_PASSWORD environment variables")

    client = MczCloudClient(username, password)
    await client.login()
    stoves = await client.get_stoves()

    if not stoves:
        sys.exit("No stove found on this MCZ account")

    node = stoves[0]["Node"]
    stove_id = node["Id"]
    model_id = node["ModelId"]
    sensor_set_type_id = node["SensorSetTypeId"]

    if args.command == "status":
        await client.ping(stove_id)
        state = await client.get_state(stove_id)
        status = await client.get_status(stove_id)
        print(format_status(state, status))

    elif args.command == "raw-state":
        await client.ping(stove_id)
        state = await client.get_state(stove_id)
        print(json.dumps(state, indent=2, ensure_ascii=False))

    elif args.command == "raw-status":
        await client.ping(stove_id)
        status = await client.get_status(stove_id)
        print(json.dumps(status, indent=2, ensure_ascii=False))

    elif args.command == "info":
        model = await client.get_model(model_id)
        print(f"Poêle : {node.get('Name', 'N/A')}")
        print(f"Modèle : {model.get('ModelName', 'N/A')}")
        print(f"ID : {stove_id}")
        print(f"Code unique : {node.get('UniqueCode', 'N/A')}")
        print(f"\nCommandes disponibles :")
        for mc in model.get("ModelConfigurations", []):
            print(f"\n  [{mc['ConfigurationName']}] (id: {mc['ConfigurationId']})")
            for cfg in mc.get("Configurations", []):
                vis = "✓" if cfg.get("Visible") else "·"
                rng = ""
                if cfg.get("Min") is not None and cfg.get("Max") is not None:
                    rng = f" [{cfg['Min']}–{cfg['Max']}]"
                mappings = ""
                if cfg.get("Mappings"):
                    mappings = f" {cfg['Mappings']}"
                print(f"    {vis} {cfg['SensorName']} ({cfg['Type']}{rng}{mappings})")

    elif args.command in ("power", "temp", "silent", "eco", "chrono", "power-level", "mode", "fan"):
        model = await client.get_model(model_id)

        if args.command == "power":
            mapping_key = "on" if args.value == "on" else "off"
            mapped = find_sensor_with_mapping(model, "stato_stufa", mapping_key)
            if mapped:
                sensor_id, configuration_id, value = mapped
            else:
                sys.exit("Sensor 'stato_stufa' not found. Run 'info'.")
        elif args.command == "temp":
            result = find_sensor(model, "set_amb1")
            if not result:
                sys.exit("Sensor 'set_amb1' not found. Run 'info'.")
            sensor_id, configuration_id = result
            value = float(args.value)
        elif args.command == "power-level":
            result = find_sensor(model, "potenza_att")
            if not result:
                sys.exit("Sensor 'potenza_att' not found. Run 'info'.")
            sensor_id, configuration_id = result
            value = int(args.value)
        elif args.command == "silent":
            result = find_sensor(model, "silent_enabled")
            if not result:
                sys.exit("Sensor 'silent_enabled' not found. Run 'info'.")
            sensor_id, configuration_id = result
            value = True if args.value == "on" else False
        elif args.command == "eco":
            result = find_sensor(model, "att_eco")
            if not result:
                sys.exit("Sensor 'att_eco' not found. Run 'info'.")
            sensor_id, configuration_id = result
            value = True if args.value == "on" else False
        elif args.command == "chrono":
            result = find_sensor(model, "crono_enabled")
            if not result:
                sys.exit("Sensor 'crono_enabled' not found. Run 'info'.")
            sensor_id, configuration_id = result
            value = True if args.value == "on" else False
        elif args.command == "mode":
            mapped = find_sensor_with_mapping(model, "mod_lav_att", args.value)
            if mapped:
                sensor_id, configuration_id, value = mapped
            else:
                sys.exit(f"Mode '{args.value}' not found. Run 'info'.")
        elif args.command == "fan":
            result = find_sensor(model, "set_vent_v1")
            if not result:
                sys.exit("Sensor 'set_vent_v1' not found. Run 'info'.")
            sensor_id, configuration_id = result
            value = int(args.value)

        resp = await client.activate_program(
            stove_id, model_id, sensor_set_type_id,
            configuration_id, sensor_id, value,
        )
        if resp is not None:
            print(f"OK – {args.command} → {args.value}")
        else:
            print(f"Échec de la commande {args.command}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
