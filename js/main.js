import * as THREE from "three";
import { createComms } from "./comms.js";
import {
  WEAPONS,
  emptyLoadout,
  recompute,
  offerThree,
  applyChoice,
  firstEvolvable,
  evolve,
  weaponLabel,
  PASSIVES,
} from "./loadout.js";

const MAX_HP = 5;
const ARENA = 960;
const RADAR_RANGE = 160;
const BASE_SPEED = 38;
const BOOST_SPEED = 62;
const TURN_RATE = 2.6;
const FIRE_INTERVAL = 0.16;
const ROLL_TIME = 0.42;
const ROLL_COOLDOWN = 0.55;
const I_FRAMES = 0.85;
const PROJECTILE_SPEED = 160;
const PROJECTILE_LIFE = 1.35;
const GEM_PULL = 28;
const START_HORDE = 14;
const MAX_HORDE = 64;
const HIT_R2 = 2.4;
const ACE_TIMES = [60, 180, 300, 480, 540];
const SECTOR_END = 600;

const keys = new Set();
const input = {
  yaw: 0,
  boost: false,
  roll: false,
  cut: false,
  uturn: false,
};

const THROTTLE_RATE = 0.9;
let throttle = 0;
let boostT = 0;

let running = false;
let elapsed = 0;
let hp = MAX_HP;
let kills = 0;
let iFrames = 0;
let rollT = 0;
let rollCd = 0;
let fireT = 0;
let spawnAcc = 0;
let hudAcc = 0;
let radarAcc = 0;
let lastPortrait = window.innerHeight > window.innerWidth;
let justRolled = false;
let justHit = false;
let didRoll = false;
let lastWave = 1;
let xp = 0;
let level = 1;
let xpNeed = 6;
let pendingLevels = 0;
let selecting = false;
let uTurn = 0;
let uTurnFrom = 0;
let maxHp = MAX_HP;
let loadout = emptyLoadout();
const spawnedAces = new Set();
const comms = createComms();

const projectiles = [];
const enemies = [];
const gems = [];
const pods = [];
const orbiters = [];
const caches = [];
const enemyPool = [];
const boltPool = [];
const gemPool = [];
const podPool = [];

const _fwd = new THREE.Vector3();
const _to = new THREE.Vector3();
const _origin = new THREE.Vector3();
const _up = new THREE.Vector3(0, 1, 0);
const camOffset = new THREE.Vector3();
const lookAt = new THREE.Vector3();

const clock = new THREE.Clock();
const scene = new THREE.Scene();
scene.fog = new THREE.FogExp2(0x050910, 0.0042);
scene.background = new THREE.Color(0x050910);

const isCoarse = matchMedia("(pointer: coarse)").matches;
const isPortrait = () => window.innerHeight > window.innerWidth;

const camera = new THREE.PerspectiveCamera(isCoarse ? 68 : 58, 1, 0.1, 700);
const renderer = new THREE.WebGLRenderer({ antialias: false, alpha: false, powerPreference: "high-performance" });
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.domElement.style.pointerEvents = "none";
document.body.prepend(renderer.domElement);

scene.add(new THREE.HemisphereLight(0x8eb0c8, 0x0a1218, 0.9));
const keyLight = new THREE.DirectionalLight(0xc8e4ff, 0.85);
keyLight.position.set(40, 80, 20);
scene.add(keyLight);

const geo = {
  cone: new THREE.ConeGeometry(0.55, 3.4, 5),
  hull: new THREE.BoxGeometry(0.7, 0.38, 2.1),
  cockpit: new THREE.SphereGeometry(0.28, 6, 5),
  fin: new THREE.ConeGeometry(0.16, 0.9, 3),
  engine: new THREE.CylinderGeometry(0.16, 0.22, 0.35, 6),
  bolt: new THREE.CylinderGeometry(0.05, 0.05, 1.4, 4),
  gem: new THREE.OctahedronGeometry(0.35, 0),
  pod: new THREE.BoxGeometry(0.7, 0.7, 0.7),
  orb: new THREE.OctahedronGeometry(0.28, 0),
  eBody: new THREE.ConeGeometry(0.42, 2.4, 4),
  eWing: new THREE.BoxGeometry(2.1, 0.06, 0.7),
  cache: new THREE.OctahedronGeometry(0.55, 0),
  ring: new THREE.TorusGeometry(1.35, 0.07, 6, 18),
};

function lambert(color, emissive = 0x000000, ei = 0) {
  return new THREE.MeshLambertMaterial({ color, emissive, emissiveIntensity: ei, flatShading: true });
}

const mats = {
  pBody: lambert(0xe8f2f6),
  pHull: lambert(0x2a9d8f),
  pWing: new THREE.MeshLambertMaterial({ color: 0x1b4d4a, flatShading: true, side: THREE.DoubleSide }),
  pGlass: lambert(0x7ee8ff, 0x3aa8c0, 0.35),
  pEngine: lambert(0x111820, 0x3ee0c3, 1.4),
  eBody: lambert(0x8b2e2e, 0x4a1010, 0.25),
  eWing: lambert(0x3a1018),
  bolt: new THREE.MeshBasicMaterial({ color: 0xc8fff0 }),
  gem: lambert(0x66f0ff, 0x2288aa, 0.8),
  pod: lambert(0xf0c14a, 0xaa7700, 0.7),
  orb: lambert(0xff8844, 0xff5522, 0.9),
  lock: new THREE.MeshBasicMaterial({ color: 0x88ffaa }),
  scatter: new THREE.MeshBasicMaterial({ color: 0xaad4ff }),
  mines: new THREE.MeshBasicMaterial({ color: 0xffcc66 }),
  aceRing: lambert(0xf0c14a, 0xffaa33, 0.85),
  cachePatch: lambert(0x7dffb0, 0x2a8848, 0.7),
  cacheVac: lambert(0x88d4ff, 0x2266aa, 0.7),
  cacheFlare: lambert(0xffe08a, 0xcc8800, 0.8),
};

function wingGeo(sign) {
  const g = new THREE.BufferGeometry();
  g.setAttribute(
    "position",
    new THREE.BufferAttribute(
      new Float32Array([0.1 * sign, 0.05, 0.85, 2.6 * sign, -0.22, -0.35, 0.12 * sign, 0.02, -1.25]),
      3
    )
  );
  g.computeVertexNormals();
  return g;
}
geo.wingL = wingGeo(-1);
geo.wingR = wingGeo(1);

function heading(yaw, out) {
  out.set(Math.sin(yaw), 0, Math.cos(yaw));
  return out;
}

function makePlayerShip() {
  const root = new THREE.Group();
  const body = new THREE.Mesh(geo.cone, mats.pBody);
  body.rotation.x = -Math.PI / 2;
  body.position.z = 0.2;
  const hull = new THREE.Mesh(geo.hull, mats.pHull);
  hull.position.z = 0.15;
  const cockpit = new THREE.Mesh(geo.cockpit, mats.pGlass);
  cockpit.scale.set(1, 0.7, 1.2);
  cockpit.position.set(0, 0.28, 0.15);
  const fin = new THREE.Mesh(geo.fin, mats.pWing);
  fin.rotation.x = -Math.PI / 2.6;
  fin.position.set(0, 0.45, -0.85);
  const engine = new THREE.Mesh(geo.engine, mats.pEngine);
  engine.rotation.x = Math.PI / 2;
  engine.position.z = -1.35;
  root.add(body, hull, cockpit, new THREE.Mesh(geo.wingL, mats.pWing), new THREE.Mesh(geo.wingR, mats.pWing), fin, engine);
  const glow = new THREE.PointLight(0x3ee0c3, 1.4, 10, 2);
  glow.position.z = -1.5;
  root.add(glow);
  root.userData.glow = glow;
  return root;
}

function makeEnemy() {
  const root = new THREE.Group();
  const body = new THREE.Mesh(geo.eBody, mats.eBody);
  body.rotation.x = -Math.PI / 2;
  const wing = new THREE.Mesh(geo.eWing, mats.eWing);
  wing.position.z = -0.15;
  root.add(body, wing);
  root.visible = false;
  scene.add(root);
  return root;
}

const player = makePlayerShip();
scene.add(player);

const starfield = (() => {
  const count = 900;
  const pos = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    pos[i * 3] = (Math.random() - 0.5) * 520;
    pos[i * 3 + 1] = (Math.random() - 0.5) * 180;
    pos[i * 3 + 2] = (Math.random() - 0.5) * 520;
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.BufferAttribute(pos, 3));
  const pts = new THREE.Points(
    g,
    new THREE.PointsMaterial({ color: 0xb9d4ff, size: 0.7, sizeAttenuation: true, transparent: true, opacity: 0.85 })
  );
  scene.add(pts);
  return pts;
})();

const floor = new THREE.GridHelper(ARENA * 2, 16, 0x12303a, 0x0b1c24);
floor.position.y = -18;
floor.material.transparent = true;
floor.material.opacity = 0.16;
scene.add(floor);

function wrapToArena(v) {
  const h = ARENA / 2;
  if (v.x > h) v.x = -h;
  else if (v.x < -h) v.x = h;
  if (v.z > h) v.z = -h;
  else if (v.z < -h) v.z = h;
}

function confinePlayer(dt) {
  const h = ARENA / 2 - 6;
  const p = player.position;
  let hit = false;
  if (p.x > h) {
    p.x = h;
    hit = true;
  } else if (p.x < -h) {
    p.x = -h;
    hit = true;
  }
  if (p.z > h) {
    p.z = h;
    hit = true;
  } else if (p.z < -h) {
    p.z = -h;
    hit = true;
  }
  if (hit && uTurn <= 0) {
    uTurn = 0.42;
    uTurnFrom = player.rotation.y;
  }
  if (uTurn > 0) {
    const dur = 0.42;
    uTurn -= dt;
    const t = 1 - Math.max(0, uTurn) / dur;
    const e = t * t * (3 - 2 * t);
    player.rotation.y = uTurnFrom + Math.PI * e;
  }
}

function toRadar(wx, wz, scale) {
  const dx = wx - player.position.x;
  const dz = wz - player.position.z;
  const s = Math.sin(player.rotation.y);
  const c = Math.cos(player.rotation.y);
  return { x: (dx * c - dz * s) * scale, y: -(dx * s + dz * c) * scale };
}

function spawnEnemy(boss = false) {
  const e = enemyPool.pop() || makeEnemy();
  const ang = Math.random() * Math.PI * 2;
  const dist = boss ? 55 : 70 + Math.random() * 50;
  e.position.set(player.position.x + Math.cos(ang) * dist, 0, player.position.z + Math.sin(ang) * dist);
  wrapToArena(e.position);
  e.scale.setScalar(boss ? 2.35 : 0.85);
  e.userData.boss = boss;
  e.userData.dropPod = boss;
  e.userData.hp = boss ? 26 + elapsed * 0.35 : 2 + Math.floor(elapsed / 40);
  e.userData.speed = boss ? 9 : 16 + Math.random() * 10 + Math.min(14, elapsed * 0.15);
  if (boss && !e.userData.ring) {
    const ring = new THREE.Mesh(geo.ring, mats.aceRing);
    ring.rotation.x = Math.PI / 2;
    e.add(ring);
    e.userData.ring = ring;
  }
  if (e.userData.ring) e.userData.ring.visible = boss;
  e.visible = true;
  enemies.push(e);
  return e;
}

function spawnFieldCaches() {
  const spots = [
    { x: 0, z: 88, kind: "patch", mat: mats.cachePatch },
    { x: 88, z: 0, kind: "vac", mat: mats.cacheVac },
    { x: 0, z: -88, kind: "flare", mat: mats.cacheFlare },
    { x: -88, z: 0, kind: "patch", mat: mats.cachePatch },
  ];
  for (const s of spots) {
    const mesh = new THREE.Mesh(geo.cache, s.mat);
    mesh.position.set(s.x, 0.6, s.z);
    scene.add(mesh);
    caches.push({ mesh, kind: s.kind, taken: false });
  }
}

function collectCache(c) {
  if (c.taken) return;
  c.taken = true;
  c.mesh.visible = false;
  if (c.kind === "patch") {
    hp = Math.min(maxHp, hp + 2);
    comms.say("pip", "Patch kit. Two plates sealed. Don't spend them twice.");
  } else if (c.kind === "vac") {
    const n = gems.length;
    for (const g of gems) {
      g.mesh.visible = false;
      gemPool.push(g.mesh);
    }
    gems.length = 0;
    if (n) addXp(n);
    comms.say("pip", n ? "Scoop's full. That's a lot of light." : "Scoop's dry. Kill something first.");
  } else if (c.kind === "flare") {
    let n = 0;
    for (let i = enemies.length - 1; i >= 0; i--) {
      const e = enemies[i];
      if (e.userData.boss) continue;
      recycleEnemy(e);
      n += 1;
    }
    comms.say("juno", n ? "Flare out. I can see again." : "You wasted a flare on empty sky.");
  }
}

function spawnAces() {
  for (const t of ACE_TIMES) {
    if (elapsed >= t && !spawnedAces.has(t)) {
      spawnedAces.add(t);
      spawnEnemy(true);
      comms.say("vicar", t >= SECTOR_END ? "Ace on the Well. Mercy is jumping — finish this." : "Ace inbound. Take the pod if you can.");
    }
  }
}

function recycleEnemy(e) {
  const i = enemies.indexOf(e);
  if (i >= 0) {
    enemies[i] = enemies[enemies.length - 1];
    enemies.pop();
  }
  e.visible = false;
  e.userData.boss = false;
  e.userData.dropPod = false;
  enemyPool.push(e);
}

function hurtEnemy(e, dmg) {
  if (!e.visible) return;
  e.userData.hp -= dmg;
  if (e.userData.hp > 0) return;
  dropGem(e.position.x, e.position.y, e.position.z);
  if (e.userData.dropPod) dropPod(e.position.x, e.position.z);
  recycleEnemy(e);
  kills += 1;
}

function addXp(n) {
  xp += n;
  while (xp >= xpNeed) {
    xp -= xpNeed;
    level += 1;
    xpNeed = 6 + level * 4;
    pendingLevels += 1;
  }
  if (pendingLevels && !selecting) openLevelUp();
}

function dropPod(x, z) {
  const mesh = podPool.pop() || new THREE.Mesh(geo.pod, mats.pod);
  mesh.position.set(x, 0.4, z);
  mesh.visible = true;
  if (!mesh.parent) scene.add(mesh);
  pods.push({ mesh, life: 22 });
}

function dropGem(x, y, z) {
  const mesh = gemPool.pop() || new THREE.Mesh(geo.gem, mats.gem);
  mesh.position.set(x, 0.2, z);
  mesh.visible = true;
  if (!mesh.parent) scene.add(mesh);
  gems.push({ mesh, life: 12 });
}

function bestTarget(preferFront = true, exclude = null) {
  heading(player.rotation.y, _fwd);
  let best = null;
  let bestScore = Infinity;
  for (let i = 0; i < enemies.length; i++) {
    const e = enemies[i];
    if (exclude && exclude.has(e)) continue;
    const dx = e.position.x - player.position.x;
    const dz = e.position.z - player.position.z;
    const d2 = dx * dx + dz * dz;
    if (d2 < 0.01) continue;
    const d = Math.sqrt(d2);
    const facing = (_fwd.x * dx + _fwd.z * dz) / d;
    const score = d * (preferFront && facing > 0.15 ? 0.45 : 1.25);
    if (score < bestScore) {
      bestScore = score;
      best = e;
    }
  }
  return best;
}

function fireBolt(dx, dz, opts = {}) {
  _to.set(dx, 0, dz);
  if (_to.lengthSq() < 0.0001) heading(player.rotation.y, _to);
  else _to.normalize();
  const speed = opts.speed ?? PROJECTILE_SPEED;
  const mat = opts.mat ?? mats.bolt;
  const bolt = boltPool.pop() || new THREE.Mesh(geo.bolt, mat);
  bolt.material = mat;
  bolt.scale.setScalar(opts.scale ?? loadout.stats.area);
  bolt.quaternion.setFromUnitVectors(_up, _to);
  bolt.position.copy(player.position).addScaledVector(_to, 2.2);
  bolt.visible = true;
  if (!bolt.parent) scene.add(bolt);
  projectiles.push({
    mesh: bolt,
    vx: _to.x * speed,
    vz: _to.z * speed,
    life: opts.life ?? PROJECTILE_LIFE,
    dmg: (opts.dmg ?? 1) * loadout.stats.damage,
    r2: HIT_R2 * loadout.stats.area,
  });
}

function pulseNova(radius, dmg) {
  const r2 = radius * radius;
  for (let j = enemies.length - 1; j >= 0; j--) {
    const e = enemies[j];
    const dx = e.position.x - player.position.x;
    const dz = e.position.z - player.position.z;
    if (dx * dx + dz * dz < r2) hurtEnemy(e, dmg);
  }
}

function spawnOrbiter(w) {
  const mesh = new THREE.Mesh(geo.orb, mats.orb);
  scene.add(mesh);
  orbiters.push({
    mesh,
    angle: Math.random() * Math.PI * 2,
    radius: 3.2 * loadout.stats.area * (w.evolved ? 1.45 : 1),
    speed: 2.4 + w.level * 0.25,
    dmg: (0.55 + w.level * 0.12) * loadout.stats.damage,
    life: w.evolved ? 999 : 6,
  });
}

function fireWeapon(w) {
  const def = WEAPONS[w.id];
  if (!def) return;
  const lv = w.level;
  const evo = w.evolved;
  heading(player.rotation.y, _fwd);
  if (w.id === "twin") {
    const t = bestTarget(true);
    if (!t) return;
    const dx = t.position.x - player.position.x;
    const dz = t.position.z - player.position.z;
    fireBolt(dx, dz, { dmg: 1 + lv * 0.15 });
    if (evo) fireBolt(dx + _fwd.z * 1.2, dz - _fwd.x * 1.2, { dmg: 1 + lv * 0.15 });
  } else if (w.id === "lock") {
    const n = evo ? 3 : 1;
    const used = new Set();
    for (let i = 0; i < n; i++) {
      const t = bestTarget(false, used);
      if (!t) break;
      used.add(t);
      fireBolt(t.position.x - player.position.x, t.position.z - player.position.z, {
        mat: mats.lock,
        dmg: 0.85 + lv * 0.12,
        speed: 110,
      });
    }
  } else if (w.id === "bomb") {
    spawnOrbiter(w);
  } else if (w.id === "nova") {
    pulseNova((3.4 + lv * 0.35) * loadout.stats.area * (evo ? 1.5 : 1), (1.1 + lv * 0.2) * loadout.stats.damage);
  } else if (w.id === "scatter") {
    const spread = evo ? 5 : 3;
    for (let i = 0; i < spread; i++) {
      const a = player.rotation.y + (i - (spread - 1) / 2) * 0.45;
      fireBolt(Math.sin(a), Math.cos(a), { mat: mats.scatter, dmg: 0.7 + lv * 0.1, life: 0.7 });
    }
  } else if (w.id === "mines") {
    const n = evo ? 2 : 1;
    for (let i = 0; i < n; i++) {
      fireBolt(-_fwd.x + (i ? 0.4 : 0), -_fwd.z, { mat: mats.mines, dmg: 1.4 + lv * 0.2, speed: 8, life: 5, scale: 1.4 });
    }
  }
}

function tickWeapons(dt) {
  for (const w of loadout.weapons) {
    w.cd -= dt;
    if (w.cd > 0) continue;
    const def = WEAPONS[w.id];
    w.cd = (def?.interval ?? 0.3) * loadout.stats.cooldown;
    fireWeapon(w);
  }
}

function desiredHorde() {
  const wave = 1 + Math.floor(elapsed / 18);
  return Math.min(MAX_HORDE, START_HORDE + wave * 5 + Math.floor(elapsed / 10));
}

function updateCamera(dt) {
  const portrait = isPortrait();
  if (portrait !== lastPortrait) {
    lastPortrait = portrait;
    camera.fov = portrait || isCoarse ? 72 : 55;
    camera.updateProjectionMatrix();
  }
  const back = portrait || isCoarse ? 13.5 : 8.4;
  const up = portrait || isCoarse ? 3.6 : 2.35;
  heading(player.rotation.y, _fwd);
  camOffset.copy(player.position).addScaledVector(_fwd, -back);
  camOffset.y = player.position.y + up;
  const t = 1 - Math.exp(-10 * dt);
  camera.position.lerp(camOffset, t);
  lookAt.copy(player.position).addScaledVector(_fwd, 22);
  lookAt.y = player.position.y + 0.35;
  camera.lookAt(lookAt);
}

function updatePlayer(dt) {
  let yawCmd = input.yaw;
  if (keys.has("arrowleft") || keys.has("a")) yawCmd -= 1;
  if (keys.has("arrowright") || keys.has("d")) yawCmd += 1;
  if (keys.has("arrowup") || keys.has("w")) throttle += THROTTLE_RATE * dt;
  if (keys.has("arrowdown") || keys.has("s")) throttle -= THROTTLE_RATE * dt;
  if (input.cut || keys.has("x") || keys.has("z")) throttle = 0;
  input.cut = false;
  throttle = THREE.MathUtils.clamp(throttle, 0, 1);

  if (input.boost) {
    boostT = Math.max(boostT, 0.55);
    input.boost = false;
  }
  if (keys.has("shift")) boostT = Math.max(boostT, 0.05);
  boostT = Math.max(0, boostT - dt);
  const boosting = boostT > 0;

  if (input.uturn && uTurn <= 0) {
    uTurn = 0.42;
    uTurnFrom = player.rotation.y;
  }
  input.uturn = false;

  if ((input.roll || keys.has(" ") || keys.has("r")) && rollCd <= 0 && rollT <= 0) {
    rollT = ROLL_TIME;
    rollCd = ROLL_COOLDOWN + ROLL_TIME;
    iFrames = Math.max(iFrames, ROLL_TIME + 0.08);
    justRolled = true;
    didRoll = true;
  }
  input.roll = false;

  yawCmd = THREE.MathUtils.clamp(yawCmd, -1, 1);

  if (uTurn <= 0) player.rotation.y -= yawCmd * TURN_RATE * dt;
  const cruise = BASE_SPEED * throttle * loadout.stats.speed;
  const speed = boosting ? BOOST_SPEED * Math.max(throttle, 0.4) * loadout.stats.speed : cruise;
  heading(player.rotation.y, _fwd);
  player.position.addScaledVector(_fwd, speed * dt);
  confinePlayer(dt);

  const bank = THREE.MathUtils.damp(player.rotation.z, -yawCmd * 0.55, 8, dt);
  if (rollT > 0) {
    rollT -= dt;
    player.rotation.z = bank + (1 - rollT / ROLL_TIME) * Math.PI * 2;
  } else {
    player.rotation.z = bank;
  }
  player.rotation.x = THREE.MathUtils.damp(player.rotation.x, thrust * -0.12, 8, dt);
  player.userData.glow.intensity = boosting ? 3.1 : 0.35 + throttle * 1.4;

  rollCd = Math.max(0, rollCd - dt);
  iFrames = Math.max(0, iFrames - dt);
}

function updateEnemies(dt) {
  const px = player.position.x;
  const pz = player.position.z;
  for (let i = enemies.length - 1; i >= 0; i--) {
    const e = enemies[i];
    const dx = px - e.position.x;
    const dz = pz - e.position.z;
    const d2 = dx * dx + dz * dz;
    if (d2 > 0.0001) {
      const yaw = Math.atan2(dx, dz);
      let dy = yaw - e.rotation.y;
      while (dy > Math.PI) dy -= Math.PI * 2;
      while (dy < -Math.PI) dy += Math.PI * 2;
      e.rotation.y += dy * Math.min(1, 4 * dt);
    }
    heading(e.rotation.y, _fwd);
    e.position.addScaledVector(_fwd, e.userData.speed * dt);
    wrapToArena(e.position);

    const hitR = e.userData.boss ? 16 : 3.24;
    if (d2 < hitR && iFrames <= 0) {
      hp -= 1;
      iFrames = I_FRAMES;
      justHit = true;
      if (!e.userData.boss) recycleEnemy(e);
      if (hp <= 0) endRun(false);
    }
  }
}

function recycleBolt(p, index) {
  p.mesh.visible = false;
  boltPool.push(p.mesh);
  projectiles[index] = projectiles[projectiles.length - 1];
  projectiles.pop();
}

function updateProjectiles(dt) {
  for (let i = projectiles.length - 1; i >= 0; i--) {
    const p = projectiles[i];
    p.life -= dt;
    p.mesh.position.x += p.vx * dt;
    p.mesh.position.z += p.vz * dt;
    if (p.life <= 0) {
      recycleBolt(p, i);
      continue;
    }
    const bx = p.mesh.position.x;
    const bz = p.mesh.position.z;
    for (let j = enemies.length - 1; j >= 0; j--) {
      const e = enemies[j];
      const dx = bx - e.position.x;
      const dz = bz - e.position.z;
      if (dx * dx + dz * dz < HIT_R2) {
        e.userData.hp -= 1;
        recycleBolt(p, i);
        hurtEnemy(e, p.dmg ?? 1);
        break;
      }
    }
  }
}

function updateGems(dt) {
  const px = player.position.x;
  const pz = player.position.z;
  for (let i = gems.length - 1; i >= 0; i--) {
    const g = gems[i];
    g.life -= dt;
    g.mesh.rotation.y += dt * 3;
    const dx = px - g.mesh.position.x;
    const dz = pz - g.mesh.position.z;
    const d2 = dx * dx + dz * dz;
    const pullR = GEM_PULL * loadout.stats.magnet;
    if (d2 < pullR * pullR && d2 > 0.0001) {
      const d = Math.sqrt(d2);
      const pull = (pullR - d) * 4 * dt;
      g.mesh.position.x += (dx / d) * pull;
      g.mesh.position.z += (dz / d) * pull;
    }
    if (d2 < 2 || g.life <= 0) {
      if (d2 < 2) addXp(1);
      g.mesh.visible = false;
      gemPool.push(g.mesh);
      gems[i] = gems[gems.length - 1];
      gems.pop();
    }
  }
}

function updatePods(dt) {
  const px = player.position.x;
  const pz = player.position.z;
  const pullR = 36 * loadout.stats.magnet;
  for (let i = pods.length - 1; i >= 0; i--) {
    const p = pods[i];
    p.life -= dt;
    p.mesh.rotation.x += dt * 1.4;
    p.mesh.rotation.y += dt * 2;
    const dx = px - p.mesh.position.x;
    const dz = pz - p.mesh.position.z;
    const d2 = dx * dx + dz * dz;
    if (d2 < pullR * pullR && d2 > 0.0001) {
      const d = Math.sqrt(d2);
      p.mesh.position.x += (dx / d) * 10 * dt;
      p.mesh.position.z += (dz / d) * 10 * dt;
    }
    if (d2 < 3.2) {
      const ready = firstEvolvable(loadout);
      if (ready) {
        evolve(loadout, ready);
        comms.say("pip", `${WEAPONS[ready].evoName} online. Don't waste it.`);
      } else addXp(14);
      p.mesh.visible = false;
      podPool.push(p.mesh);
      pods[i] = pods[pods.length - 1];
      pods.pop();
    } else if (p.life <= 0) {
      p.mesh.visible = false;
      podPool.push(p.mesh);
      pods[i] = pods[pods.length - 1];
      pods.pop();
    }
  }
}

function updateCaches(dt) {
  const px = player.position.x;
  const pz = player.position.z;
  for (const c of caches) {
    if (c.taken) continue;
    c.mesh.rotation.y += dt * 1.6;
    c.mesh.position.y = 0.55 + Math.sin(elapsed * 2.4) * 0.12;
    const dx = px - c.mesh.position.x;
    const dz = pz - c.mesh.position.z;
    if (dx * dx + dz * dz < 4.5) collectCache(c);
  }
}

function updateOrbiters(dt) {
  for (let i = orbiters.length - 1; i >= 0; i--) {
    const o = orbiters[i];
    o.life -= dt;
    o.angle += o.speed * dt;
    o.mesh.position.set(
      player.position.x + Math.sin(o.angle) * o.radius,
      0.3,
      player.position.z + Math.cos(o.angle) * o.radius
    );
    for (let j = enemies.length - 1; j >= 0; j--) {
      const e = enemies[j];
      const dx = o.mesh.position.x - e.position.x;
      const dz = o.mesh.position.z - e.position.z;
      if (dx * dx + dz * dz < 2.2) hurtEnemy(e, o.dmg * dt * 8);
    }
    if (o.life <= 0) {
      scene.remove(o.mesh);
      orbiters.splice(i, 1);
    }
  }
}

const radarCanvas = document.getElementById("radar-canvas");
const radarCtx = radarCanvas.getContext("2d");

function drawRadar() {
  const w = radarCanvas.width;
  const h = radarCanvas.height;
  const ctx = radarCtx;
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "rgba(8,18,24,0.2)";
  ctx.beginPath();
  ctx.arc(w / 2, h / 2, w / 2 - 2, 0, Math.PI * 2);
  ctx.fill();
  const scale = (w / 2 - 6) / RADAR_RANGE;
  const limit = (w / 2 - 5) * (w / 2 - 5);
  ctx.save();
  ctx.translate(w / 2, h / 2);
  ctx.fillStyle = "#3ee0c3";
  ctx.beginPath();
  ctx.moveTo(0, -7);
  ctx.lineTo(4.5, 6);
  ctx.lineTo(-4.5, 6);
  ctx.closePath();
  ctx.fill();
  for (let i = 0; i < enemies.length; i++) {
    const e = enemies[i];
    const { x, y } = toRadar(e.position.x, e.position.z, scale);
    if (x * x + y * y > limit) continue;
    ctx.fillStyle = e.userData.boss ? "#f0c14a" : "#ff6b4a";
    const s = e.userData.boss ? 5 : 3;
    ctx.fillRect(x - s / 2, y - s / 2, s, s);
  }
  for (const c of caches) {
    if (c.taken) continue;
    const { x, y } = toRadar(c.mesh.position.x, c.mesh.position.z, scale);
    if (x * x + y * y > limit) continue;
    ctx.fillStyle = c.kind === "patch" ? "#7dffb0" : c.kind === "vac" ? "#88d4ff" : "#ffe08a";
    ctx.fillRect(x - 2, y - 2, 4, 4);
  }
  ctx.restore();
}

const hpEl = document.getElementById("hp");
const killsEl = document.getElementById("kills");
const waveEl = document.getElementById("wave");
const timeEl = document.getElementById("time");
const lvlEl = document.getElementById("lvl");
const xpFill = document.getElementById("xp-fill");
const kitEl = document.getElementById("kit");

function bars(n, max) {
  const m = max ?? maxHp;
  const h = Math.max(0, Math.round(n));
  return "█".repeat(h) + "░".repeat(Math.max(0, m - h));
}

function formatTime(t) {
  const m = Math.floor(t / 60);
  const s = Math.floor(t % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}

function syncHud() {
  hpEl.textContent = bars(hp, maxHp);
  hpEl.style.color = hp <= 2 ? "#ff6b4a" : "#3ee0c3";
  killsEl.textContent = String(kills);
  waveEl.textContent = String(1 + Math.floor(elapsed / 18));
  timeEl.textContent = formatTime(elapsed);
  lvlEl.textContent = String(level);
  xpFill.style.width = `${Math.min(100, (xp / xpNeed) * 100)}%`;
  const bits = loadout.weapons.map((w) => weaponLabel(w));
  for (const p of loadout.passives) {
    const def = PASSIVES[p.id];
    bits.push(`${def ? def.name : p.id} ${p.level}`);
  }
  kitEl.textContent = bits.join("  ·  ");
  const pct = Math.round(throttle * 100);
  document.getElementById("thr-fill").style.height = `${boostT > 0 ? 100 : pct}%`;
  document.getElementById("thr-fill").classList.toggle("boost", boostT > 0);
  document.getElementById("thr-pct").textContent = String(boostT > 0 ? "BST" : pct);
}

function resize() {
  camera.aspect = innerWidth / innerHeight;
  camera.fov = isPortrait() || isCoarse ? 72 : 55;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
}

function clearExtras() {
  for (const p of pods) {
    p.mesh.visible = false;
    podPool.push(p.mesh);
  }
  pods.length = 0;
  for (const o of orbiters) scene.remove(o.mesh);
  orbiters.length = 0;
  for (const c of caches) scene.remove(c.mesh);
  caches.length = 0;
}

function resetRun() {
  elapsed = 0;
  hp = MAX_HP;
  maxHp = MAX_HP;
  kills = 0;
  xp = 0;
  level = 1;
  xpNeed = 6;
  pendingLevels = 0;
  selecting = false;
  uTurn = 0;
  throttle = 0.35;
  boostT = 0;
  loadout = emptyLoadout();
  recompute(loadout);
  spawnedAces.clear();
  iFrames = 1.2;
  rollT = 0;
  rollCd = 0;
  fireT = 0;
  player.position.set(0, 0, 0);
  player.rotation.set(0, 0, 0);
  while (enemies.length) recycleEnemy(enemies[0]);
  for (const p of projectiles) {
    p.mesh.visible = false;
    boltPool.push(p.mesh);
  }
  projectiles.length = 0;
  for (const g of gems) {
    g.mesh.visible = false;
    gemPool.push(g.mesh);
  }
  gems.length = 0;
  clearExtras();
  document.getElementById("levelup").classList.remove("show");
  spawnFieldCaches();
  for (let i = 0; i < START_HORDE; i++) spawnEnemy();
  justRolled = false;
  justHit = false;
  didRoll = false;
  lastWave = 1;
  syncHud();
  comms.startMission();
}

function endRun(won) {
  running = false;
  selecting = false;
  document.getElementById("levelup").classList.remove("show");
  comms.update(elapsed, { hp, kills, wave: lastWave, justRolled: false, justHit: false, didRoll, dead: !won });
  const overlay = document.getElementById("overlay");
  overlay.classList.add("show");
  overlay.querySelector("h1").textContent = won ? "MERCY IS AWAY" : "HULL LOST";
  overlay.querySelector(".tag").textContent = `Lv ${level} · ${kills} kills · ${formatTime(elapsed)}`;
  overlay.querySelector("p:nth-of-type(2)").textContent = won
    ? "The seed-ship jumped. The Well is quiet — for a second."
    : "The horde does not stop. Launch again.";
  document.getElementById("start-btn").textContent = "RELAUNCH";
}

function openLevelUp() {
  selecting = true;
  const offers = offerThree(loadout);
  const root = document.getElementById("levelup-cards");
  root.replaceChildren();
  offers.forEach((choice, i) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "up-card";
    btn.innerHTML = `<span class="tag">${choice.tag}</span><h3>${i + 1}. ${choice.label}</h3><p>${choice.detail}</p>`;
    btn.addEventListener("click", () => pickCard(choice));
    root.appendChild(btn);
  });
  window.__offers = offers;
  document.getElementById("levelup").classList.add("show");
  syncHud();
}

function pickCard(choice) {
  applyChoice(loadout, choice);
  maxHp = MAX_HP + loadout.stats.hpBonus;
  if (choice.kind === "heal" || choice.id === "plating") hp = Math.min(maxHp, hp + 1);
  pendingLevels = Math.max(0, pendingLevels - 1);
  document.getElementById("levelup").classList.remove("show");
  selecting = false;
  syncHud();
  if (pendingLevels) openLevelUp();
}

function tick() {
  const dt = Math.min(0.05, clock.getDelta());
  if (running && !selecting) {
    elapsed += dt;
    spawnAcc += dt;
    if (spawnAcc > 0.4) {
      spawnAcc = 0;
      const want = desiredHorde();
      while (enemies.length < want) spawnEnemy();
    }
    spawnAces();
    tickWeapons(dt);
    updatePlayer(dt);
    updateEnemies(dt);
    updateProjectiles(dt);
    updateGems(dt);
    updatePods(dt);
    updateOrbiters(dt);
    updateCaches(dt);
    if (elapsed >= SECTOR_END) {
      endRun(true);
    }
    starfield.position.x = player.position.x;
    starfield.position.z = player.position.z;
    updateCamera(dt);
    radarAcc += dt;
    if (radarAcc > 0.05) {
      radarAcc = 0;
      drawRadar();
    }
    hudAcc += dt;
    if (hudAcc > 0.1) {
      hudAcc = 0;
      syncHud();
    }
    lastWave = 1 + Math.floor(elapsed / 18);
    comms.update(elapsed, {
      hp,
      kills,
      wave: lastWave,
      justRolled,
      justHit,
      didRoll,
      dead: false,
    });
    justRolled = false;
    justHit = false;
    player.visible = iFrames <= 0 || ((elapsed * 24) & 1) === 0;
  } else {
    player.rotation.y += dt * 0.25;
    updateCamera(dt * 0.6);
  }
  comms.tick(dt);
  renderer.render(scene, camera);
  requestAnimationFrame(tick);
}

let lastTap = 0;
let lastTapDir = 0;
window.addEventListener("keydown", (e) => {
  const k = e.key.toLowerCase();
  if (!e.repeat) keys.add(k);
  if ([" ", "arrowup", "arrowdown", "arrowleft", "arrowright"].includes(k)) e.preventDefault();
  if (selecting && window.__offers) {
    const n = Number(e.key);
    if (n >= 1 && n <= window.__offers.length) pickCard(window.__offers[n - 1]);
  }
  if (e.repeat) return;
  if (k !== "a" && k !== "d" && k !== "arrowleft" && k !== "arrowright") return;
  const dir = k === "a" || k === "arrowleft" ? -1 : 1;
  const now = performance.now();
  if (dir === lastTapDir && now - lastTap < 260) input.roll = true;
  lastTap = now;
  lastTapDir = dir;
});
window.addEventListener("keyup", (e) => keys.delete(e.key.toLowerCase()));

const touch = { sx: 0, sy: 0, px: 0, py: 0, t: 0, lastTap: 0 };
window.addEventListener(
  "touchstart",
  (e) => {
    const t = e.changedTouches[0];
    touch.sx = touch.px = t.clientX;
    touch.sy = touch.py = t.clientY;
    touch.t = performance.now();
  },
  { passive: true }
);
window.addEventListener(
  "touchmove",
  (e) => {
    const t = e.changedTouches[0];
    const dx = t.clientX - touch.px;
    const dy = t.clientY - touch.py;
    touch.px = t.clientX;
    touch.py = t.clientY;
    input.yaw = THREE.MathUtils.clamp((dx / (innerWidth * 0.18)) * 2.2, -1, 1);
  },
  { passive: true }
);
window.addEventListener(
  "touchend",
  () => {
    input.yaw = 0;
    const now = performance.now();
    const dx = touch.px - touch.sx;
    const dy = touch.py - touch.sy;
    const dist = Math.hypot(dx, dy);
    const held = now - touch.t;
    if (held < 240 && dist > 40) {
      if (Math.abs(dx) > Math.abs(dy) * 1.25) input.roll = true;
      else if (dy < 0) input.boost = true;
      else input.uturn = true;
    } else if (held < 220 && dist < 22) {
      if (now - touch.lastTap < 280) input.cut = true;
      touch.lastTap = now;
    }
  },
  { passive: true }
);

document.getElementById("start-btn").addEventListener("click", () => {
  document.getElementById("overlay").classList.remove("show");
  resetRun();
  running = true;
  clock.getDelta();
});

window.addEventListener("resize", resize);
resize();
updateCamera(1);
tick();
