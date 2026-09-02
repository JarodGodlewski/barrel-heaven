#!/usr/bin/env python3
"""Seed Birddog Softworks Barrel Heaven kanban. Idempotent."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path("/workspace/barrel-heaven")
if not ROOT.is_dir():
    ROOT = Path(__file__).resolve().parents[2]

HERMES = "/opt/hermes/bin/hermes"
BOARD = "barrel-heaven"
WORKDIR = str(ROOT)


def run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=str(ROOT), text=True, capture_output=True)


def hermes(args: list[str]) -> str:
    cmd = [HERMES, "kanban", "--board", BOARD, *args]
    p = run(cmd)
    out = (p.stdout or "") + (p.stderr or "")
    if p.returncode != 0:
        print(out, file=sys.stderr)
        raise SystemExit(p.returncode)
    print(out.rstrip())
    return out


def main() -> int:
    hermes(["init"])
    hermes(["boards", "set-default-workdir", BOARD, WORKDIR])
    cards = [
        (
            "Classics cites → docs/research/CLASSICS.md",
            "bh-classics-v1",
            ROOT / "docs" / "STUDIO_BRIEF_CLASSICS.md",
        ),
        (
            "Writer's room → docs/research/WRITERS_ROOM.md",
            "bh-writers-v1",
            ROOT / "docs" / "STUDIO_BRIEF_CLASSICS.md",
        ),
    ]
    for title, key, body in cards:
        text = body.read_text(encoding="utf-8") if body.is_file() else title
        hermes(
            [
                "create",
                title,
                "--assignee",
                "default",
                "--workspace",
                f"dir:{WORKDIR}",
                "--created-by",
                "Jarod",
                "--priority",
                "10",
                "--idempotency-key",
                key,
                "--goal",
                "--goal-max-turns",
                "24",
                "--max-runtime",
                "2h",
                "--body",
                text,
            ]
        )
    hermes(["list"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
