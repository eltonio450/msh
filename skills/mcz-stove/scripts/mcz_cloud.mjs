#!/usr/bin/env node
/**
 * MCZ Maestro Cloud API CLI – controls MCZ pellet stoves via the official cloud.
 * Uses the same API as the MCZ Maestro mobile app. Zero dependencies (Node 18+ fetch).
 *
 * Env vars: MCZ_USERNAME, MCZ_PASSWORD
 *
 * Usage:
 *   node mcz_cloud.mjs status
 *   node mcz_cloud.mjs power on|off
 *   node mcz_cloud.mjs temp <value>
 *   node mcz_cloud.mjs power-level <1-5>
 *   node mcz_cloud.mjs silent on|off
 *   node mcz_cloud.mjs eco on|off
 *   node mcz_cloud.mjs chrono on|off
 *   node mcz_cloud.mjs mode manual|dynamic|comfort|overnight|power
 *   node mcz_cloud.mjs fan <0-6>
 *   node mcz_cloud.mjs info
 *   node mcz_cloud.mjs raw-state
 *   node mcz_cloud.mjs raw-status
 */

const BASE = "https://s.maestro.mcz.it";
const LOGIN_URL = `${BASE}/hlapi/v1.0/Authorization/Login`;
const STOVES_URL = `${BASE}/hlapi/v1.0/Nav/FirstVisibleObjectsPaginated`;
const TENANT_ID = "7c201fd8-42bd-4333-914d-0f5822070757";

// ── API client ──────────────────────────────────────────────────────────────

class MczClient {
  constructor(username, password) {
    this.username = username;
    this.password = password;
    this.token = null;
  }

  async login() {
    const res = await fetch(LOGIN_URL, {
      method: "POST",
      headers: { "content-type": "application/json", tenantid: TENANT_ID },
      body: JSON.stringify({ username: this.username, password: this.password }),
    });
    const data = await res.json();
    if (!data.Token) throw new Error(`Login failed: ${JSON.stringify(data)}`);
    this.token = data.Token;
  }

  async request(method, url, body = null, retry = true) {
    if (!this.token) await this.login();
    const opts = { method, headers: { "auth-token": this.token } };
    if (body !== null) {
      opts.headers["content-type"] = "application/json";
      opts.body = JSON.stringify(body);
    }
    const res = await fetch(url, opts);
    if (res.status === 401 && retry) {
      await this.login();
      return this.request(method, url, body, false);
    }
    return res.json();
  }

  stoves() { return this.request("POST", STOVES_URL, {}); }
  state(id) { return this.request("GET", `${BASE}/mcz/v1.0/Appliance/${id}/State`); }
  status(id) { return this.request("GET", `${BASE}/mcz/v1.0/Appliance/${id}/Status`); }
  model(id) { return this.request("GET", `${BASE}/hlapi/v1.0/Model/${id}`); }
  ping(id) { return this.request("POST", `${BASE}/mcz/v1.0/Program/Ping/${id}`); }

  activate(stoveId, modelId, sensorSetTypeId, configurationId, sensorId, value) {
    return this.request("POST", `${BASE}/mcz/v1.0/Program/ActivateProgram/${stoveId}`, {
      ModelId: modelId,
      ConfigurationId: configurationId,
      SensorSetTypeId: sensorSetTypeId,
      Commands: [{ SensorId: sensorId, Value: value }],
    });
  }
}

// ── Sensor lookup ───────────────────────────────────────────────────────────

const PREFIXES = ["", "m1_", "m2_", "m3_"];

function findSensor(model, sensorName) {
  const target = sensorName.toLowerCase();
  for (const prefix of PREFIXES) {
    for (const mc of model.ModelConfigurations || []) {
      for (const cfg of mc.Configurations || []) {
        if (cfg.SensorName?.toLowerCase() === `${prefix}${target}`) {
          return { sensorId: cfg.SensorId, configId: mc.ConfigurationId };
        }
      }
    }
  }
  return null;
}

function findSensorWithMapping(model, sensorName, mappingKey) {
  const target = sensorName.toLowerCase();
  for (const prefix of PREFIXES) {
    for (const mc of model.ModelConfigurations || []) {
      for (const cfg of mc.Configurations || []) {
        if (
          cfg.SensorName?.toLowerCase() === `${prefix}${target}` &&
          cfg.Mappings && mappingKey in cfg.Mappings
        ) {
          return {
            sensorId: cfg.SensorId,
            configId: mc.ConfigurationId,
            value: cfg.Mappings[mappingKey],
          };
        }
      }
    }
  }
  return null;
}

// ── Status formatting ───────────────────────────────────────────────────────

const STOVE_STATES = {
  0: "Éteint", 1: "Vérification", 2: "Nettoyage (froid)", 3: "Chargement pellets (froid)",
  4: "Démarrage 1 (froid)", 5: "Démarrage 2 (froid)", 6: "Nettoyage (chaud)",
  7: "Chargement pellets (chaud)", 8: "Démarrage 1 (chaud)", 9: "Démarrage 2 (chaud)",
  10: "Stabilisation", 11: "Puissance 1", 12: "Puissance 2", 13: "Puissance 3",
  14: "Puissance 4", 15: "Puissance 5", 30: "Diagnostics", 31: "Allumé",
  40: "Extinction", 41: "Refroidissement", 42: "Nettoyage (bas)", 43: "Nettoyage (haut)",
  44: "Déblocage vis", 45: "Auto Éco", 46: "Veille",
  50: "Erreur: échec allumage", 51: "Erreur: pas de flamme",
  52: "Erreur: surchauffe réservoir", 53: "Erreur: température fumées trop haute",
};

const MODE_LABELS = {
  manual: "Manuel", dynamic: "Dynamique", comfort: "Confort",
  overnight: "Nuit", power: "Puissance",
};

const OFF_STATES = new Set([0, 40, 41, 44, 45, 46]);

function formatStatus(state, status) {
  const lines = [];
  const s = (key) => status[key] ?? state[key];

  lines.push(`Connecté : ${s("IsConnected") ? "Oui" : "Non"}`);

  const stato = status.stato_stufa;
  const stateLabel = STOVE_STATES[stato] ?? status.Status ?? state.state ?? "Inconnu";
  const isOn = typeof stato === "number" && stato >= 1 && stato <= 46 && !OFF_STATES.has(stato);
  lines.push(`Allumé : ${isOn ? "Oui" : "Non"}`);
  lines.push(`État : ${stateLabel}`);

  const mode = status.mod_lav_att || state.mod_lav_att;
  if (mode) lines.push(`Mode : ${MODE_LABELS[mode] || mode}`);

  const tempAmb = status.temp_amb_install ?? state.temp_amb_install;
  if (tempAmb != null) lines.push(`Température ambiante : ${tempAmb}°C`);

  const tempTarget = status.set_amb1 ?? state.set_amb1;
  if (tempTarget != null) lines.push(`Température cible : ${tempTarget}°C`);

  if (state.temp_fumi != null) lines.push(`Température fumées : ${state.temp_fumi}°C`);

  const power = state.potenza_att ?? status.potenza_att;
  if (power != null) lines.push(`Niveau de puissance : ${power}`);

  if (status.set_vent_v1 != null) lines.push(`Ventilateur : ${status.set_vent_v1}`);

  const eco = s("att_eco");
  if (eco != null) lines.push(`Mode éco : ${eco ? "Oui" : "Non"}`);

  if (status.silent_enabled != null) lines.push(`Mode silencieux : ${status.silent_enabled ? "Oui" : "Non"}`);

  const chrono = s("crono_enabled");
  if (chrono != null) lines.push(`Chronostat : ${chrono ? "Oui" : "Non"}`);

  const pellet = s("sens_liv_pellet");
  if (pellet != null) lines.push(`Capteur pellets : ${pellet ? "OK" : "Bas/absent"}`);

  if (state.IsInError || status.IsInError) lines.push(`ERREUR : ${state.last_alarm ?? "inconnu"}`);

  if (status.ore_prox_manut != null) lines.push(`Heures avant maintenance : ${status.ore_prox_manut}h`);

  return lines.join("\n");
}

// ── CLI ─────────────────────────────────────────────────────────────────────

function die(msg) { console.error(msg); process.exit(1); }

const USAGE = `Usage: node mcz_cloud.mjs <command> [args]

Commands:
  status                État actuel du poêle
  power on|off          Allumer / éteindre
  temp <5-35>           Température cible (°C)
  power-level <1-5>     Niveau de puissance
  mode <mode>           Mode: manual|dynamic|comfort|overnight|power
  fan <0-6>             Ventilateur (0-5, 6=auto)
  silent on|off         Mode silencieux
  eco on|off            Mode éco
  chrono on|off         Chronostat
  info                  Modèle et commandes disponibles
  raw-state             JSON brut état
  raw-status            JSON brut statut`;

async function main() {
  const [cmd, arg] = process.argv.slice(2);
  if (!cmd) die(USAGE);

  const username = process.env.MCZ_USERNAME;
  const password = process.env.MCZ_PASSWORD;
  if (!username || !password) die("Set MCZ_USERNAME and MCZ_PASSWORD env vars");

  const client = new MczClient(username, password);
  await client.login();
  const stoves = await client.stoves();
  if (!Array.isArray(stoves) || !stoves.length) die("No stove found on this MCZ account");

  const node = stoves[0].Node;
  const { Id: stoveId, ModelId: modelId, SensorSetTypeId: sensorSetTypeId } = node;

  if (cmd === "status") {
    await client.ping(stoveId);
    const [state, status] = await Promise.all([client.state(stoveId), client.status(stoveId)]);
    console.log(formatStatus(state, status));

  } else if (cmd === "raw-state") {
    await client.ping(stoveId);
    console.log(JSON.stringify(await client.state(stoveId), null, 2));

  } else if (cmd === "raw-status") {
    await client.ping(stoveId);
    console.log(JSON.stringify(await client.status(stoveId), null, 2));

  } else if (cmd === "info") {
    const model = await client.model(modelId);
    console.log(`Poêle : ${node.Name || "N/A"}`);
    console.log(`Modèle : ${model.ModelName || "N/A"}`);
    console.log(`ID : ${stoveId}`);
    console.log(`Code unique : ${node.UniqueCode || "N/A"}`);
    console.log(`\nCommandes disponibles :`);
    for (const mc of model.ModelConfigurations || []) {
      console.log(`\n  [${mc.ConfigurationName}] (id: ${mc.ConfigurationId})`);
      for (const cfg of mc.Configurations || []) {
        const vis = cfg.Visible ? "✓" : "·";
        const rng = cfg.Min != null && cfg.Max != null ? ` [${cfg.Min}–${cfg.Max}]` : "";
        const maps = cfg.Mappings ? ` ${JSON.stringify(cfg.Mappings)}` : "";
        console.log(`    ${vis} ${cfg.SensorName} (${cfg.Type}${rng}${maps})`);
      }
    }

  } else if (["power", "temp", "power-level", "silent", "eco", "chrono", "mode", "fan"].includes(cmd)) {
    if (arg == null) die(`Missing argument for '${cmd}'`);
    const model = await client.model(modelId);
    let sensorId, configId, value;

    if (cmd === "power") {
      if (arg !== "on" && arg !== "off") die("power: expected on|off");
      const m = findSensorWithMapping(model, "stato_stufa", arg);
      if (!m) die("Sensor 'stato_stufa' not found. Run 'info'.");
      ({ sensorId, configId, value } = m);

    } else if (cmd === "temp") {
      const v = parseFloat(arg);
      if (isNaN(v) || v < 5 || v > 35) die("temp: expected 5–35");
      const r = findSensor(model, "set_amb1");
      if (!r) die("Sensor 'set_amb1' not found. Run 'info'.");
      ({ sensorId, configId } = r);
      value = v;

    } else if (cmd === "power-level") {
      const v = parseInt(arg);
      if (isNaN(v) || v < 1 || v > 5) die("power-level: expected 1–5");
      const r = findSensor(model, "potenza_att");
      if (!r) die("Sensor 'potenza_att' not found. Run 'info'.");
      ({ sensorId, configId } = r);
      value = v;

    } else if (cmd === "mode") {
      const valid = ["manual", "dynamic", "comfort", "overnight", "power"];
      if (!valid.includes(arg)) die(`mode: expected ${valid.join("|")}`);
      const m = findSensorWithMapping(model, "mod_lav_att", arg);
      if (!m) die(`Mode '${arg}' not found. Run 'info'.`);
      ({ sensorId, configId, value } = m);

    } else if (cmd === "fan") {
      const v = parseInt(arg);
      if (isNaN(v) || v < 0 || v > 6) die("fan: expected 0–6");
      const r = findSensor(model, "set_vent_v1");
      if (!r) die("Sensor 'set_vent_v1' not found. Run 'info'.");
      ({ sensorId, configId } = r);
      value = v;

    } else {
      if (arg !== "on" && arg !== "off") die(`${cmd}: expected on|off`);
      const sensorMap = { silent: "silent_enabled", eco: "att_eco", chrono: "crono_enabled" };
      const r = findSensor(model, sensorMap[cmd]);
      if (!r) die(`Sensor '${sensorMap[cmd]}' not found. Run 'info'.`);
      ({ sensorId, configId } = r);
      value = arg === "on";
    }

    const resp = await client.activate(stoveId, modelId, sensorSetTypeId, configId, sensorId, value);
    if (resp != null) {
      console.log(`OK – ${cmd} → ${arg}`);
    } else {
      die(`Échec de la commande ${cmd}`);
    }

  } else {
    die(USAGE);
  }
}

main().catch((e) => { console.error(e.message); process.exit(1); });
