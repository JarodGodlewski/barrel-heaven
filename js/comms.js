import { createBlobCam } from "./blobcam.js";

const CAST = {
  hatch: { name: "HATCH", ch: "WING-2", mood: "talk" },
  juno: { name: "JUNO", ch: "WING-3", mood: "smug" },
  pip: { name: "PIP", ch: "NEST-1", mood: "talk" },
  vicar: { name: "VICAR", ch: "COMMAND", mood: "idle" },
  kite: { name: "KITE", ch: "UNKNOWN", mood: "glare" },
};

export function createComms() {
  const root = document.getElementById("comms");
  const nameEl = document.getElementById("comms-name");
  const chEl = document.getElementById("comms-ch");
  const lineEl = document.getElementById("comms-line");
  const blob = createBlobCam(document.getElementById("comms-blob"));

  const queue = [];
  const heard = new Set();
  let hideAt = 0;
  let showing = false;
  let closing = false;

  function say(who, text, hold = 4.1, mood) {
    queue.push({ who, text, hold, mood });
  }

  function sayOnce(id, who, text, hold, mood) {
    if (heard.has(id)) return;
    heard.add(id);
    say(who, text, hold, mood);
  }

  function present(next) {
    const speaker = CAST[next.who] || CAST.hatch;
    nameEl.textContent = speaker.name;
    chEl.textContent = speaker.ch;
    lineEl.textContent = next.text;
    blob.setSpeaker(next.who, {
      talking: true,
      mood: next.mood || speaker.mood || "talk",
    });
    root.hidden = false;
    root.classList.add("on");
    showing = true;
    closing = false;
    hideAt = performance.now() + next.hold * 1000;
  }

  function showNext() {
    const next = queue.shift();
    if (!next) {
      showing = false;
      closing = false;
      root.classList.remove("on");
      return;
    }
    present(next);
  }

  function reset() {
    queue.length = 0;
    heard.clear();
    showing = false;
    closing = false;
    hideAt = 0;
    root.classList.remove("on");
    root.hidden = true;
  }

  function startMission() {
    reset();
    say("vicar", "All-range, Rook. Hold the Well until Mercy finishes her jump. Weapons free.");
    say("hatch", "They'll crawl up your six. Barrel roll when the tracers get close, kid.");
    say("pip", "Four caches on the cardinals. Green patches hull. Blue scoops motes. Gold is a flare.");
  }

  function update(elapsed, ev) {
    if (elapsed > 16) sayOnce("juno-hello", "juno", "Try to keep up. I'll mop whoever gets bored of you.");
    if (elapsed > 22 && !ev.didRoll) {
      sayOnce("hatch-nudge", "hatch", "That's a barrel roll. R or Space. Or flick the stick. Do it before they sew you shut.");
    }
    if (ev.justRolled) sayOnce("hatch-roll", "hatch", "That's it! Keep that roll in your pocket.");
    if (ev.justHit) sayOnce("pip-hit", "pip", "Hull ping! I can patch from here — don't make a habit.", 4.1, "worry");
    if (ev.wave === 2) sayOnce("wave2", "vicar", "Second curtain. Mercy is still spooling. Do not let them through.");
    if (elapsed > 38) sayOnce("pip-guns", "pip", "G-diffuser's singing. Your guns are running hot. That's the good kind of hot.");
    if (ev.kills >= 25) sayOnce("juno-kills", "juno", "Not bad for a freelancer. Don't get cute.");
    if (ev.wave === 3) sayOnce("wave3", "vicar", "Mercy at sixty percent. Hold the Well.");
    if (elapsed > 78) sayOnce("kite", "kite", "Pretty lights, Rook. The Banner sends its regards.");
    if (ev.wave >= 4) sayOnce("wave4", "vicar", "Jump window is opening. One more stretch.");
    if (elapsed > 118) sayOnce("mercy", "vicar", "Mercy is away. The Well is yours if you want the rest of them.");
    if (ev.hp <= 2 && ev.hp > 0) sayOnce("hatch-leak", "hatch", "You're leaking, kid. Fly smart.", 4.1, "worry");
    if (ev.dead) {
      queue.length = 0;
      closing = false;
      say("juno", "Rook is down! Rook is—", 2.4, "shout");
      say("vicar", "We've lost the Well. Pull what's left.", 3.2);
    }
  }

  function tick(dt) {
    const now = performance.now();
    if (showing && !closing && now >= hideAt) {
      blob.sleep();
      closing = true;
      hideAt = now + 300;
    } else if (showing && closing && now >= hideAt) {
      showNext();
    } else if (!showing && queue.length) {
      showNext();
    }
    blob.tick(dt);
    blob.draw();
  }

  return { reset, startMission, update, tick, say, sayOnce };
}
