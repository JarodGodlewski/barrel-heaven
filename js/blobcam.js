function lerp(a, b, t) {
  return a + (b - a) * t;
}

function lerpAng(a, b, t) {
  let d = b - a;
  while (d > Math.PI) d -= Math.PI * 2;
  while (d < -Math.PI) d += Math.PI * 2;
  return a + d * t;
}

const KEYS = [
  "r",
  "amp",
  "lobes",
  "phase",
  "squash",
  "stretch",
  "rot",
  "lx",
  "ly",
  "lw",
  "lh",
  "lr",
  "rx",
  "ry",
  "rw",
  "rh",
  "rr",
  "mouth",
  "mx",
  "my",
  "mw",
  "mh",
  "accent",
  "ax",
  "ay",
];

function blank(partial = {}) {
  return {
    r: 34,
    amp: 0,
    lobes: 0,
    phase: 0,
    squash: 1,
    stretch: 1,
    rot: 0,
    body: [12, 22, 28],
    eye: [236, 246, 252],
    lx: -9,
    ly: -4,
    lw: 8,
    lh: 14,
    lr: 0.12,
    rx: 10,
    ry: -4,
    rw: 8,
    rh: 14,
    rr: -0.12,
    mouth: 0,
    mx: 0,
    my: 13,
    mw: 10,
    mh: 4,
    accent: 0,
    ax: 22,
    ay: -22,
    lookX: 0,
    lookY: 0,
    ...partial,
  };
}

const PILOT = {
  hatch: blank({
    r: 33,
    amp: 0.05,
    lobes: 2,
    body: [32, 40, 34],
    lx: -10,
    ly: -1,
    lw: 7,
    lh: 11,
    rx: 10,
    ry: -1,
    rw: 7,
    rh: 11,
    lookX: 0.08,
    lookY: 0.04,
  }),
  juno: blank({
    r: 32,
    amp: 0.09,
    lobes: 3,
    phase: 0.35,
    body: [16, 38, 58],
    lx: -8,
    ly: -5,
    lw: 5.5,
    lh: 15,
    lr: 0.42,
    rx: 10,
    ry: 0,
    rw: 5,
    rh: 9,
    rr: -0.48,
    lookX: 0.32,
    lookY: -0.08,
  }),
  pip: blank({
    r: 36,
    amp: 0.11,
    lobes: 4,
    body: [24, 62, 36],
    lx: -12,
    ly: -1,
    lw: 11,
    lh: 11,
    rx: 12,
    ry: -1,
    rw: 11,
    rh: 11,
    lookX: -0.1,
    lookY: 0.12,
  }),
  vicar: blank({
    r: 31,
    amp: 0.015,
    lobes: 0,
    body: [18, 22, 28],
    lx: -8,
    ly: -6,
    lw: 6,
    lh: 7.5,
    rx: 8,
    ry: -6,
    rw: 6,
    rh: 7.5,
    lookX: 0,
    lookY: 0,
  }),
  kite: blank({
    r: 33,
    amp: 0.2,
    lobes: 3,
    phase: 0.12,
    body: [56, 16, 18],
    lx: -9,
    ly: -6,
    lw: 7,
    lh: 13,
    lr: 0.55,
    rx: 10,
    ry: -6,
    rw: 7,
    rh: 13,
    rr: -0.55,
    accent: 1,
    lookX: -0.28,
    lookY: 0.06,
  }),
};

const MOOD = {
  idle: {},
  talk: { mouth: 0.55, mh: 5.5 },
  smug: { lh: 7, rh: 4.5, ly: 1.2, ry: 2.4, lr: 0.35, mouth: 0.2 },
  worry: { lw: 11, lh: 16, rw: 11, rh: 16, ly: -7, ry: -7, mouth: 0.35, mh: 3 },
  glare: { lr: 0.62, rr: -0.62, ly: -6, ry: -6, lh: 12, rh: 12, mouth: 0.15 },
  shout: { mouth: 1, mh: 9, squash: 0.9, stretch: 1.1, amp: 0.08 },
  rest: { r: 6.5, amp: 0, mouth: 0, lw: 2, lh: 2, rw: 2, rh: 2, accent: 0 },
};

function compose(who, moodName, talking) {
  const base = PILOT[who] || PILOT.vicar;
  const mood = MOOD[moodName] || MOOD.idle;
  const s = blank({ ...base, ...mood, body: base.body.slice(), eye: base.eye.slice() });
  if (talking && s.mouth < 0.35) s.mouth = 0.45;
  const turn = s.lookX;
  s.lx += turn * 9;
  s.rx += turn * 9;
  s.ly += s.lookY * 6;
  s.ry += s.lookY * 6;
  const near = 1 + Math.abs(turn) * 0.12;
  const far = 1 - Math.abs(turn) * 0.18;
  if (turn >= 0) {
    s.rw *= near;
    s.rh *= near;
    s.lw *= far;
    s.lh *= far;
  } else {
    s.lw *= near;
    s.lh *= near;
    s.rw *= far;
    s.rh *= far;
  }
  s.rot = turn * 0.18;
  return s;
}

function rgb(c, a = 1) {
  return `rgba(${c[0] | 0},${c[1] | 0},${c[2] | 0},${a})`;
}

function capsule(ctx, x, y, w, h, rot, fill) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rot);
  const rw = Math.max(0.4, w / 2);
  const rh = Math.max(0.4, h / 2);
  const r = Math.min(rw, rh);
  ctx.beginPath();
  if (ctx.roundRect) ctx.roundRect(-rw, -rh, rw * 2, rh * 2, r);
  else {
    ctx.moveTo(-rw + r, -rh);
    ctx.arcTo(rw, -rh, rw, rh, r);
    ctx.arcTo(rw, rh, -rw, rh, r);
    ctx.arcTo(-rw, rh, -rw, -rh, r);
    ctx.arcTo(-rw, -rh, rw, -rh, r);
  }
  ctx.fillStyle = fill;
  ctx.fill();
  ctx.restore();
}

function drawBlob(ctx, s, cx, cy) {
  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate(s.rot);
  ctx.scale(s.stretch, s.squash);
  ctx.beginPath();
  const steps = 48;
  for (let i = 0; i <= steps; i++) {
    const th = (i / steps) * Math.PI * 2;
    const rad = s.r * (1 + s.amp * Math.cos(s.lobes * (th + s.phase)));
    const x = Math.cos(th) * rad;
    const y = Math.sin(th) * rad;
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.closePath();
  ctx.fillStyle = rgb(s.body);
  ctx.fill();
  const eyeFill = rgb(s.eye);
  capsule(ctx, s.lx, s.ly, s.lw, s.lh, s.lr, eyeFill);
  capsule(ctx, s.rx, s.ry, s.rw, s.rh, s.rr, eyeFill);
  if (s.mouth > 0.04) capsule(ctx, s.mx, s.my, s.mw * s.mouth, s.mh * (0.55 + s.mouth), 0, eyeFill);
  if (s.accent > 0.05) {
    ctx.beginPath();
    ctx.arc(s.ax, s.ay, 5.5 * s.accent, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(80,170,255,${0.95 * s.accent})`;
    ctx.fill();
    ctx.lineWidth = 2;
    ctx.strokeStyle = "rgba(240,248,255,0.85)";
    ctx.stroke();
  }
  ctx.restore();
}

export function createBlobCam(canvas) {
  const ctx = canvas.getContext("2d");
  let cur = compose("vicar", "idle", false);
  let goal = compose("vicar", "idle", false);
  const vel = {};
  for (const k of KEYS) vel[k] = 0;
  let who = "vicar";
  let talking = false;
  let clock = 0;
  let blink = 1.8;
  let wink = false;
  const stiff = 18;
  const damp = 0.78;

  function setSpeaker(id, opts = {}) {
    who = id;
    talking = !!opts.talking;
    const mood = opts.mood || (talking ? "talk" : "idle");
    goal = compose(who, mood, talking);
  }

  function sleep() {
    talking = false;
    goal = compose(who, "rest", false);
  }

  function spring() {
    const dt = 1 / 60;
    for (const k of KEYS) {
      const force = (goal[k] - cur[k]) * stiff;
      vel[k] = vel[k] * damp + force * dt;
      cur[k] += vel[k] * dt * 8;
    }
    cur.body = cur.body.map((v, i) => lerp(v, goal.body[i], 0.12));
    cur.eye = cur.eye.map((v, i) => lerp(v, goal.eye[i], 0.12));
    cur.lookX = lerpAng(cur.lookX || 0, goal.lookX || 0, 0.12);
    cur.lookY = lerp(cur.lookY || 0, goal.lookY || 0, 0.12);
  }

  function tick(dt) {
    clock += dt;
    spring();
    if (talking) {
      const w = 0.5 + 0.5 * Math.sin(clock * 13);
      cur.mouth = 0.22 + 0.7 * Math.max(0, w);
      cur.mh = 3.2 + 5.2 * Math.max(0, w);
      cur.ly += Math.sin(clock * 8.5) * 0.28;
      cur.ry += Math.sin(clock * 8.5 + 0.7) * 0.28;
    }
    blink -= dt;
    if (blink < 0) {
      blink = 1.8 + Math.random() * 2.6;
      wink = Math.random() < 0.22;
    }
    if (blink < 0.09) {
      if (wink) cur.lh *= 0.14;
      else {
        cur.lh *= 0.14;
        cur.rh *= 0.14;
      }
    }
    const breathe = 1 + Math.sin(clock * 2.1) * 0.022;
    cur.squash *= breathe;
    cur.stretch *= 2 - breathe;
  }

  function draw() {
    const w = canvas.width;
    const h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = "#071018";
    ctx.fillRect(0, 0, w, h);
    drawBlob(ctx, cur, w / 2, h / 2 + 4);
  }

  return { setSpeaker, tick, draw, sleep };
}
