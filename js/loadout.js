export const WEAPON_SLOTS = 4;
export const PASSIVE_SLOTS = 4;
export const WEAPON_MAX = 5;

export const WEAPONS = {
  twin: {
    id: "twin",
    name: "Twin Laser",
    tag: "HARDPOINT",
    desc: "Paired cannons. Favors what's in front of you.",
    interval: 0.16,
    evolve: "coolant",
    evoName: "Storm Array",
    evoDesc: "A wall of bolts. The Well goes white.",
  },
  lock: {
    id: "lock",
    name: "Lock-On",
    tag: "HARDPOINT",
    desc: "Homing slugs. Hatch would approve of the computer.",
    interval: 0.42,
    evolve: "targeting",
    evoName: "Swarm Lock",
    evoDesc: "Three seekers. They do not miss often.",
  },
  bomb: {
    id: "bomb",
    name: "Smart Charge",
    tag: "HARDPOINT",
    desc: "Charges orbit the hull and chew whatever gets close.",
    interval: 1.1,
    evolve: "gyro",
    evoName: "Halo Charge",
    evoDesc: "A ring that never stops.",
  },
  nova: {
    id: "nova",
    name: "Nova Pulse",
    tag: "HARDPOINT",
    desc: "Shock the air around the ship.",
    interval: 1.35,
    evolve: "plating",
    evoName: "Shock Halo",
    evoDesc: "A bigger bite. Hull sings.",
  },
  scatter: {
    id: "scatter",
    name: "Scatter Banks",
    tag: "HARDPOINT",
    desc: "Side guns. Good when they come from everywhere.",
    interval: 0.38,
    evolve: "afterburner",
    evoName: "Crossfire",
    evoDesc: "A fan of light. Nothing is a six anymore.",
  },
  mines: {
    id: "mines",
    name: "Mine Rack",
    tag: "HARDPOINT",
    desc: "Drops mines in your wake.",
    interval: 0.85,
    evolve: "scoop",
    evoName: "Minefield",
    evoDesc: "The trail behind you is a problem for them.",
  },
};

export const PASSIVES = {
  coolant: { id: "coolant", name: "Coolant Loop", tag: "SYSTEM", desc: "Hardpoints cycle faster.", stat: "cooldown", per: 0.12 },
  afterburner: { id: "afterburner", name: "Afterburner", tag: "SYSTEM", desc: "More speed. More of the map.", stat: "speed", per: 0.1 },
  plating: { id: "plating", name: "Hull Plating", tag: "SYSTEM", desc: "+1 max hull and a patch.", stat: "hpBonus", per: 1 },
  scoop: { id: "scoop", name: "Mote Scoop", tag: "SYSTEM", desc: "Pull XP motes from farther out.", stat: "magnet", per: 0.22 },
  gyro: { id: "gyro", name: "Gyro Rig", tag: "SYSTEM", desc: "Bolts and pulses hit a wider cone.", stat: "area", per: 0.14 },
  targeting: { id: "targeting", name: "Targeting Core", tag: "SYSTEM", desc: "Everything hits harder.", stat: "damage", per: 0.18 },
};

export function emptyLoadout() {
  return {
    weapons: [{ id: "twin", level: 1, cd: 0, evolved: false }],
    passives: [],
    stats: { cooldown: 1, speed: 1, damage: 1, area: 1, magnet: 1, hpBonus: 0 },
  };
}

export function recompute(loadout) {
  const s = { cooldown: 1, speed: 1, damage: 1, area: 1, magnet: 1, hpBonus: 0 };
  for (const p of loadout.passives) {
    const def = PASSIVES[p.id];
    if (!def) continue;
    if (def.stat === "cooldown") s.cooldown *= 1 - def.per * p.level;
    else if (def.stat === "hpBonus") s.hpBonus += def.per * p.level;
    else s[def.stat] += def.per * p.level;
  }
  s.cooldown = Math.max(0.4, s.cooldown);
  loadout.stats = s;
  return s;
}

export function canEvolve(loadout, weaponId) {
  const w = loadout.weapons.find((x) => x.id === weaponId);
  const def = WEAPONS[weaponId];
  if (!w || !def || w.evolved || w.level < WEAPON_MAX) return false;
  return loadout.passives.some((p) => p.id === def.evolve);
}

export function evolve(loadout, weaponId) {
  const w = loadout.weapons.find((x) => x.id === weaponId);
  if (!w || !canEvolve(loadout, weaponId)) return false;
  w.evolved = true;
  return true;
}

export function firstEvolvable(loadout) {
  return loadout.weapons.find((w) => canEvolve(loadout, w.id))?.id || null;
}

function ownedWeapon(loadout, id) {
  return loadout.weapons.find((w) => w.id === id);
}

function ownedPassive(loadout, id) {
  return loadout.passives.find((p) => p.id === id);
}

export function offerThree(loadout) {
  const pool = [];
  for (const def of Object.values(WEAPONS)) {
    const have = ownedWeapon(loadout, def.id);
    if (have) {
      if (!have.evolved && have.level < WEAPON_MAX) {
        pool.push({ kind: "weapon", id: def.id, label: `${def.name} +1`, detail: `Level ${have.level + 1}`, tag: def.tag });
      }
    } else if (loadout.weapons.length < WEAPON_SLOTS) {
      pool.push({ kind: "weapon", id: def.id, label: def.name, detail: def.desc, tag: def.tag });
    }
  }
  for (const def of Object.values(PASSIVES)) {
    const have = ownedPassive(loadout, def.id);
    if (have) {
      if (have.level < 5) {
        pool.push({ kind: "passive", id: def.id, label: `${def.name} +1`, detail: `Level ${have.level + 1}`, tag: def.tag });
      }
    } else if (loadout.passives.length < PASSIVE_SLOTS) {
      pool.push({ kind: "passive", id: def.id, label: def.name, detail: def.desc, tag: def.tag });
    }
  }
  for (const w of loadout.weapons) {
    if (canEvolve(loadout, w.id)) {
      const def = WEAPONS[w.id];
      pool.push({ kind: "evolve", id: w.id, label: def.evoName, detail: def.evoDesc, tag: "EVOLVE" });
    }
  }
  if (!pool.length) {
    pool.push({ kind: "heal", id: "patch", label: "Field Patch", detail: "Restore 1 hull.", tag: "REPAIR" });
  }
  const picks = [];
  const bag = pool.slice();
  while (picks.length < 3 && bag.length) {
    const i = Math.floor(Math.random() * bag.length);
    picks.push(bag.splice(i, 1)[0]);
  }
  return picks;
}

export function applyChoice(loadout, choice) {
  if (choice.kind === "weapon") {
    const have = ownedWeapon(loadout, choice.id);
    if (have) have.level += 1;
    else loadout.weapons.push({ id: choice.id, level: 1, cd: 0, evolved: false });
  } else if (choice.kind === "passive") {
    const have = ownedPassive(loadout, choice.id);
    if (have) have.level += 1;
    else loadout.passives.push({ id: choice.id, level: 1 });
  } else if (choice.kind === "evolve") {
    evolve(loadout, choice.id);
  }
  recompute(loadout);
  return choice.kind === "heal" || choice.id === "plating";
}

export function weaponLabel(w) {
  const def = WEAPONS[w.id];
  if (!def) return w.id;
  return w.evolved ? def.evoName : `${def.name} ${w.level}`;
}
