#!/usr/bin/env python3
"""Fill Barrel Heaven board with writing / flow / progression cards. Idempotent."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

HERMES = "/opt/hermes/bin/hermes"
BOARD = "barrel-heaven"
WORKDIR = "/workspace/barrel-heaven"
ROOT = Path(WORKDIR)
if not ROOT.is_dir():
    ROOT = Path(__file__).resolve().parents[2]
    WORKDIR = str(ROOT)

CLASSICS = "t_62d5431e"
WRITERS = "t_35e007a4"

FOOT = """
LAW: studio/CONSTITUTION.md, docs/WORLD.md, docs/PROGRESSION.md, docs/STUDIO_BRIEF_CLASSICS.md.
No code. No main.gd. No new radio voices. No iceberg dump. No LAD/Lanes.
xAI grok-4.6. Chair questions max 5 at the end.
Workspace: /workspace/barrel-heaven
"""


def hermes(args: list[str]) -> str:
    cmd = [HERMES, "kanban", "--board", BOARD, *args]
    p = subprocess.run(cmd, cwd=WORKDIR, text=True, capture_output=True)
    out = (p.stdout or "") + (p.stderr or "")
    print(out.rstrip())
    if p.returncode != 0:
        raise SystemExit(p.returncode)
    return out


def create(title: str, key: str, body: str, parents: list[str], priority: str = "8") -> None:
    args = [
        "create",
        title,
        "--assignee",
        "default",
        "--workspace",
        f"dir:{WORKDIR}",
        "--created-by",
        "Jarod",
        "--priority",
        priority,
        "--idempotency-key",
        key,
        "--goal",
        "--goal-max-turns",
        "20",
        "--max-runtime",
        "90m",
        "--body",
        body.strip() + "\n" + FOOT,
    ]
    for p in parents:
        args.extend(["--parent", p])
    hermes(args)


def main() -> int:
    hermes(["boards", "set-default-workdir", BOARD, WORKDIR])

    create(
        "Radio bible → docs/research/RADIO_BIBLE.md",
        "bh-radio-bible-v1",
        """Role: creative-director.
One page per voice: Hatch, Pip, Kite. Allowed jokes, banned sermons, how they name each job (Well / Wake / Dry Mouth / Gold Paint / Lock) in ONE line.
Ending A vs B vs C: who speaks, who shuts up. Juno silhouette only on B. No Vicar.
Output: docs/research/RADIO_BIBLE.md""",
        [WRITERS],
        "9",
    )
    create(
        "Ending A/B/C beat sheets → docs/research/ENDINGS.md",
        "bh-endings-v1",
        """Role: creative-director.
A = radio + hangar, no cine. B = the only movie (true string, hardest). C = greedy smirk, Yolks, no bow.
Beat sheet per ending: what we SEE, what we never say, length. Payoff lives on B only.
Output: docs/research/ENDINGS.md""",
        [WRITERS],
        "9",
    )
    create(
        "Veil cut list → docs/research/VEIL_CUTS.md",
        "bh-veil-v1",
        """Role: creative-director.
Table-read WORLD.md Writer's room. Cut tweets, slogans, shock-jock Hatch. Keep Banner-as-rotted-office, Nest competence, Hitchhiker bureaucracy as weather.
Bogons: silent brick barge only. No 42, no towel, no poetry.
Output: docs/research/VEIL_CUTS.md keep/cut/rewrite.""",
        [WRITERS],
        "8",
    )
    create(
        "One-hole level flow → docs/research/LEVEL_FLOW.md",
        "bh-level-flow-v1",
        """Role: craft-researcher.
Five jobs are attitudes toward ONE hole, two lips — not five planets.
For each (Well, Scrap Wake, Dry Mouth, Gold Paint, the Lock): clock, what you fly through, radio one-liner, how it forks.
Steal SF64 route + OutRun visible forks. Reject wiki secrets.
Output: docs/research/LEVEL_FLOW.md""",
        [CLASSICS],
        "9",
    )
    create(
        "Secret verbs → forks → docs/research/SECRETS.md",
        "bh-secrets-v1",
        """Role: craft-researcher.
Every fork is a one-finger verb already in the Well: medal (no hull drop), hop-pack, stay after Mercy, off-cardinal buoy, Kite hears you, no-bomb on Lock.
Map verb → next job. Isaac recipe vs Star Fox one-sitting. Unlocks forever, true string still that night.
Output: docs/research/SECRETS.md""",
        [CLASSICS],
        "8",
    )
    create(
        "True-string length budget → docs/research/STRING_CLOCK.md",
        "bh-string-clock-v1",
        """Role: craft-researcher.
True string Well 10 + Wake + Gold Paint + Lock. If fat, Wake/Paint are 4–5 min encores (no Mercy clock).
Recommend clocks. Chair feel later. Do not add a sixth job.
Output: docs/research/STRING_CLOCK.md""",
        [CLASSICS],
        "7",
    )
    create(
        "Printed stats (VS twist) → docs/research/STATS_DOOR.md",
        "bh-stats-door-v1",
        """Role: craft-researcher.
VS brokenness = one sheet everything multiplies. Nest names already locked: Punch Coolant Span Knots Volley Hang Scoop Plating.
Kit door shows these. Map each to weapons/hop/bomb. If a hardpoint ignores a print, that's a bug (note it, don't code).
Output: docs/research/STATS_DOOR.md""",
        [CLASSICS],
        "9",
    )
    create(
        "Hangar / chits / Yolk → docs/research/HANGAR_YOLK.md",
        "bh-hangar-yolk-v1",
        """Role: craft-researcher.
VS powerups + golden egg, Nest clothes. Chits not coins. Yolk gated by Dry Mouth. Infinite +1 on a printed stat per kit.
Do not build. Design the sink and the gate. Meta waits for Architecture phase 4 — say so on the page.
Output: docs/research/HANGAR_YOLK.md""",
        [CLASSICS],
        "7",
    )
    create(
        "Unlock table (verbs) → docs/research/UNLOCKS.md",
        "bh-unlocks-v1",
        """Role: craft-researcher.
Three kits: Rook default, Spare crate (1 Well clear), Banner dart (3 clears or Kite).
Jobs/marks on the door. Verbs not essays. No 20 characters. Galleon last.
Output: docs/research/UNLOCKS.md""",
        [CLASSICS],
        "7",
    )
    create(
        "Kit trio stat sheet → docs/research/KITS.md",
        "bh-kits-v1",
        """Role: craft-researcher.
Rook even 1.0s. Spare crate: Plating/Span, slow Knots. Banner dart: Coolant/Knots, glass Plating.
Print the eight numbers. Select screen is a stat sheet with a silhouette, not lore.
Output: docs/research/KITS.md""",
        [CLASSICS],
        "6",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
