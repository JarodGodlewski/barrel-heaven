# Stats door — one sheet, everything multiplies

Research pass for Barrel Heaven. Mechanics, not lore. Do not implement from this file. Do not grow `main.gd`. Do not invent radio voices. Do not dump iceberg on screen.

Locked while reading: Nest names **Punch Coolant Span Knots Volley Hang Scoop Plating**. Kit door shows these. Same eight on select, pause, Pip's wrench. If a hardpoint ignores a print, that is a bug — note it, don't code. Meta (hangar, Yolk, kits) waits for Architecture phase 4. In-run math can land now.

Sibling: `docs/research/KITS.md` owns the three hulls' numbers. This file owns how the eight hit weapons / hop / Q. Names stay Nest. Never print Might / Cooldown / Area / Amount on the door.

---

## How to read

1. **Cite** — game, year, source.
2. **Did** — what they actually built.
3. **Nest-clothes** — steal / reject / how the print hits weapons, hop, Q.
4. **Now** — what this cart already multiplies (read-only). Ignore = bug.

---

## Why one sheet

### Vampire Survivors (2021)

**Cite.** Luca Galante / poncle. Player stats on the *character door* before a run, again on pause (wiki: Player stats, PowerUps, Weapons). Noclip: characters began as a stat sheet plus a starting weapon; unique rules came later because "just stats" got ridiculous as the roster grew. PowerUps are tiny forever +% into the same list (Might, Cooldown, Area, Amount, Duration, MoveSpeed, Magnet, Max Health). Amount PowerUp is one rank: **+1 projectile, all weapons**, 5,000 gold. Duration PowerUp +15% per rank. Cooldown PowerUp is 2.5% faster per rank, floor 10% remaining. Weapons each declare which player stats they scale; King Bible "scales with all stat bonuses. Best with Speed, Duration, and Area." Amount is *extra* shots (base 0), not a multiplier. Some weapons print "Ignores Duration." Limit Break dumps extra levels into the same numbers.

**Did.** Runs break because every toy multiplies a short list, not because there are more toys. The door *is* the build. In-run weapons all read those numbers. Gold buys the same numbers forever. Evolution is a pair, not a lore beat.

**Nest-clothes.** Steal the loop, already locked in `docs/PROGRESSION.md`. Eight Nest words, not twenty-six VS stats. Reject Armor, Recovery, Luck, Growth, Greed, Curse, Revival, Charm, projectile **Speed** as a ninth print (VS split Speed vs MoveSpeed on purpose; we keep Knots as the ship). Reject "this gun ignores Duration" as a design pattern — our law is the opposite: ignore is a bug. Reject 40 characters. Three kits, then the galleon.

### Magic Survival (2019)

**Cite.** NK Games. Wiki: Attack is a number every spell multiplies (Fireball 350% of Attack). All-magic cooldown is asymptotic. Research between runs is a gold sink into the same stats (Intellect, Fast Casting, Arcane Effuse, Concentration, Explorer, Haste, Vitality). Duration only applies to magics that *have* a duration.

**Did.** One stick, one person-sheet, arena fills until the screen is the enemy. Story is a loading line.

**Nest-clothes.** Steal: Punch is the number every hardpoint multiplies. Coolant is global interval. Hang only lengthens things that already live. Reject the research-tree spreadsheet on day one (hangar +1s wait for phase 4). Dying to the wave is the teacher.

### Crimsonland (2003)

**Cite.** 10tons. Survival / Rush / Quest. Perks as the build. Almost no story on purpose. CLASSICS.md already stole loadouts-with-Nest-names.

**Nest-clothes.** Rook / Spare crate / Banner dart are biases on this sheet, not novels. Numbers live in KITS.md. Do not add a perk-every-level that pauses more than the 3-card.

---

## The eight (locked)

Same table as `docs/PROGRESSION.md`. Repeated so this file can be the door spec.

| Print | VS analog | What it is | In-run system today |
|-------|-----------|------------|---------------------|
| **Punch** | Might | all damage | Targeting Core (`damage` +0.18/lv) |
| **Coolant** | Cooldown | fire interval (lower = hotter) | Coolant Loop (`cooldown` x0.88/lv, floor 0.4) |
| **Span** | Area | bolt size, nova, mines, orbit radius | Gyro Rig (`area` +0.14/lv) |
| **Knots** | MoveSpeed | cruise, boost, hop hang + distance | Afterburner (`speed` +0.10/lv) |
| **Volley** | Amount | extra bolts / orbs / mines | **none** |
| **Hang** | Duration | orbit / nova lifetime; hop if a second lever | **none** |
| **Scoop** | Magnet | shard pull | Mote Scoop (`magnet` +0.22/lv) |
| **Plating** | Max Health | hull | Hull Plating (`hp_bonus` +1/lv, also a patch) |

VS Amount is a **flat extra** (base 0, cap 10). Might / Area / Duration / MoveSpeed / Magnet are **percents** (base 100%). Coolant is an inverted percent (lower multiplier = hotter). Plating on this cart is a **flat hull plate**, not VS's +10% Max Health — Nest hull is 5 boxes, not a 100-point bar. Keep it flat.

KITS.md prints Volley **1.0** on the door as even (no extra bolt) and refuses Gennaro +1 on a hull. Hangar / Yolk may still add extras later. Door 1.0 and engine +N extras can live together if 1.0 means "+0 extras." Chair 1.

Kit base x hangar powerups x yolks x in-run systems = this flight. Weapons / hop / Q all read those numbers.


---

## Map — six hardpoints

LEVEL1 names. Intervals from the `.tres`. Counts below are *base / evolved* as the cart fires them today.

| Hardpoint | VS cousin | Punch | Coolant | Span | Knots | Volley | Hang | Scoop | Plating |
|-----------|-----------|-------|---------|------|-------|--------|------|-------|---------|
| **twin** Twin Laser to Storm Array (0.16s) | Magic Wand / Whip | dmg | interval | bolt scale + hit | — | extra bolts (today 1 / 2) | bolt life | — | — |
| **lock** Lock-On to Swarm Lock (0.42s) | Magic Wand (homing) | dmg | interval | bolt scale + hit | — | extra seekers (today 1 / 3) | bolt life | — | — |
| **bomb** Smart Charge to Halo Charge (1.1s) | King Bible | dmg | interval | orbit radius + chew | — | extra charges (today 1 / 1) | orbit life (today 6s / never) | — | — |
| **nova** Nova Pulse to Shock Halo (1.35s) | Garlic | dmg | interval | pulse radius | — | extra rings / pulses (today 1) | pulse lifetime (today instant) | — | — |
| **scatter** Scatter Banks to Crossfire (0.38s) | Knife fan / Axe | dmg | interval | bolt scale + hit | — | extra banks (today 3 / 5) | bolt life (today 0.7s) | — | — |
| **mines** Mine Rack to Minefield (0.85s) | Laurel / litter | dmg | interval | mine size + hit | — | extra drops (today 1 / 2) | mine life (today 5s) | — | — |

Dashes are *not applicable* (the print has nothing to multiply on that toy). That is legal. A filled cell that the code does not read is a bug.

**Volley is extra, not double.** First +1 on Twin is what makes the name true. Evolved Storm Array is already +1; Volley stacks on top, same as VS Amount on a level-2 Whip.

**Hang on nova.** PROGRESSION already says orbit/nova lifetime. Garlic lives. Our nova is a one-frame pulse. Until it hangs, Hang has nothing to multiply — that is a bug, not an "ignores Duration" exception.

**Knots does not mean muzzle velocity.** VS kept projectile Speed as its own stat. We rejected the ninth print. Bolts stay at their constants (160 / lock 110 / mines 8). Afterburner is the ship, not the slug.

**Scoop does not feed guns.** Magnet is shard pull. Mines evolve *with* the Scoop *system* (LEVEL1 pair); that is an evolution key, not Scoop-the-print scaling mine damage.

**Plating does not feed guns.** Nova evolves with the Plating *system*; same distinction. Punch is the damage print.

PROGRESSION Span row also lists "magnet radius." Scoop is the magnet print. Two prints cannot own one number unless Chair says Span fattens the pull *and* Scoop is the only card that writes it. KITS.md kept Span→magnet. This file still flags it (Chair 4).

---

## Map — hop

Hop is a verb, not a hardpoint. PROGRESSION already: Knots feeds cruise, boost, **hop hang + distance**.

| Print | Hop |
|-------|-----|
| Punch | — (hop does not deal damage) |
| Coolant | — (not a fire interval) |
| Span | — (unless a later Heresy: hop drops mines / nova on land) |
| **Knots** | cruise and boost already. **Must** lengthen hang *and* carry (distance / height). |
| Volley | — |
| **Hang** | second lever *only if Chair wants one*. Otherwise weapons-only. |
| Scoop | — |
| Plating | — |

Hold-to-hang already bleeds throttle. Knots that only buy more fuel while the ship dies in the air is half a card. Distance is the other half: height, or how far the hull still travels while up. CLASSICS.md: if a speed card does not change the camera's confidence, the card is a bug.

Roll is not on this sheet. Coolant does not shorten roll recovery unless Chair adds it later. Don't.

---

## Map — Q (smart bomb)

The panic button. Not the Smart Charge hardpoint. One-finger legal. The Lock later refuses it (No-bomb True). Flare cache is a *field chicken*, not this button — flare can stay a full clear.

| Print | Q |
|-------|-----|
| **Punch** | nova damage (and boss chunk) |
| Coolant | — (it is a spent charge, not an interval) |
| **Span** | blast radius |
| Knots | — |
| **Volley** | extra pulses / extra rings, or nothing if Chair says panic is one bang |
| **Hang** | lingering shock, or nothing if Chair says flash is instant |
| Scoop | — |
| Plating | — |

VS Rosary / clock-clear does not read Might. Our Q already multiplies Punch. Once Punch is on it, Span belongs too — a glass dart with no Span should not clear the same sky as a crate. Volley/Hang on Q are Chair (question 5).


---

## What the cart does today (ignore = bug)

Read-only. `loadout` sheet is six keys: `cooldown, speed, damage, area, magnet, hp_bonus`. No Volley. No Hang.

| Reader | Reads | Ignores (bug) |
|--------|-------|----------------|
| All six hardpoints | Coolant on interval. Punch on dmg. | **Volley** (counts are evolved-only literals: 1/2, 1/3, 1, 1, 3/5, 1/2). **Hang** (lives are literals: bolts 1.35, scatter 0.7, mines 5.0, orbit 6 / never, nova 0). |
| twin / lock / scatter bolts | Punch. Coolant. Span written onto `r2` and default scale. | **Span never consumed.** Hit test uses constant `HIT_R2`, not the stored `r2`. Gyro looks like it works. It does not. |
| mines | Punch. Coolant. | **Span visual skipped** (`scale: 1.4` overrides the area default). Same dead `r2`. Hang literal 5s. Volley literal 1/2. |
| Smart Charge orbiters | Punch. Coolant. Span on *orbit* radius. | **Span chew radius is 2.2**, not area. Hang 6s / 999. Volley always 1. |
| nova | Punch. Coolant. Span on pulse radius. | **Hang** (instant). **Volley** (one pulse). |
| hop | Knots on `hop_fuel` (hang time). Knots on cruise/boost while up. | **Knots distance/height** (`HOP_HEIGHT` 18, rise/land constants). Hang print does not exist. |
| Q | Punch (`10 * damage`, boss `8 * damage`). | **Span** (radius 150). Volley/Hang not in the sheet. |
| gems / pods | Scoop (`GEM_PULL * magnet`, pods 36). | — (legal). |
| hull | Plating (`MAX_HP + hp_bonus`). | — (legal). |
| flare cache / vac cache | none | Not hardpoints. Do not "fix" them onto the sheet. |

PROGRESSION beat 0 already named the hole: finish Volley and Hang so a speed card actually lengthens hop and a volley card actually adds bolts. Two extra facts since that sentence:

- Span on bolts is a ghost. The write is there; the hit is not.
- Knots already lengthens hop *fuel*. It does not lengthen hop *carry*. The speed-card sentence is half-true.

No in-run card writes Volley or Hang. Six systems fill six of eight prints. Four passive slots. VS also has more passives than slots — you draft. We cannot add two systems without Chair cutting two, or Volley/Hang living as **sheet cards** that do not occupy a system slot (closer to VS Amount PowerUp / Limit Break than to Empty Tome). KITS.md already parks Amount as hangar / Yolk, not a hull bias.

Coolant floor 0.4x (VS floor 0.1x). Not a bug. A 10-minute Well does not want 90% CDR.

---

## Kit door

Galante: the character door is a stat sheet plus a starting weapon. Ours: **stat sheet with a silhouette**, not a lore page (`docs/PROGRESSION.md`). Isaac marks stay tiny (Well / Wake / Mouth / Paint / Lock). Do not put flavour text per mark. Do not explain Wells.

Show the eight Nest words, even at 1.0 (KITS.md: a blank that means "default" is a wiki). Coolant is inverted — a 0.76x cycle is *hotter*, not worse. Door must not look like a penalty. KITS.md Chair already asks heat-bar vs raw 0.80. This file does not re-ask.

Later kits (do not build; numbers in KITS.md):

| Kit | Bias on this sheet |
|-----|--------------------|
| Rook's hull | even 1.0s |
| Spare crate | Plating / Span, slow Knots |
| Banner dart | Coolant / Knots, glass Plating |

Hangar +1s are VS PowerUps in Nest clothes: cheap, repeatable, same eight. Chits, not gold coins. Yolk is +1 to **one** printed stat on this kit, Dry Mouth gated. Limit break: four hardpoints at lv5, extra levels dump into a random print.

---

## Reject

- Ninth print (projectile Speed, Luck, Recovery, Armor, Growth, Greed, Curse).
- "Ignores Duration" as a feature. Instant toys must either grow a Hang or Chair must mark them N/A in this file.
- Span stealing Scoop unless Chair keeps PROGRESSION's magnet clause (Chair 4).
- A wrench-panel essay. Pip names the gadget, then the cost. The door is numbers.
- Shop XP replacing hop and roll.
- Cloning Spinach / Empty Tome / Duplicator names. Systems already have Nest names.
- Building hangar / Yolk / three kits while Main is the god-class.
- A unique starting hardpoint per kit (KITS.md). Twin Laser on all three.

---

## Forced contradictions vs locked docs?

None that require a silent patch.

- `docs/PROGRESSION.md` Span row lists "magnet radius." Scoop is the magnet print. Two prints cannot own one number. **Chair, do not silently patch.** KITS.md kept the clause.
- Beat-0 sentence mixes Hang with "a speed card actually lengthens hop." Speed is Knots. Hang is Duration. Leave the bible; this file splits them.
- LEVEL1 Vicar at 0:00 still contradicts WORLD.md. Not this sheet's job. Already a Chair call in CLASSICS.md / WRITERS_ROOM.md.
- KITS.md Volley 1.0 on the door vs VS Amount base 0. Display vs engine. Chair 1, not a patch.

Leave WORLD.md and PROGRESSION.md alone.

---

## Chair questions (max 5)

1. **Volley math.** VS Amount is +N extra shots (base 0). KITS.md prints Volley 1.0 as even (no extra) and parks +1 on hangar / Yolk. Confirm: door 1.0 means +0 extras; a Volley card / Yolk is +N, not xN — first extra is what twins Twin Laser.
2. **Hop levers.** Knots owns hang *and* distance (PROGRESSION + CLASSICS), or is Hang a second hop lever? Recommend Knots-only on hop so the eight stay readable.
3. **Instant flashes.** Nova and (maybe) Q have no lifetime. Must they grow a Hang (lingering shock) so the print is not a dummy, or is N/A legal for a one-frame pulse?
4. **Span vs Scoop.** Cut "magnet radius" off the Span row so Scoop is the only pull number? KITS.md kept Span→magnet.
5. **Q and the sheet.** Punch already. Span on radius too? Volley/Hang on the panic button, or one bang like a rosary?

No new stage names. No code. No new enemy types. No new radios.
