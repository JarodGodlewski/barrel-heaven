#!/usr/bin/env python3
"""Install Birddog Softworks Barrel Heaven plugin into HERMES_HOME."""
from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def hermes_home() -> Path:
    raw = os.environ.get("HERMES_HOME", "").strip()
    return Path(raw) if raw else Path("/opt/data")


def main() -> int:
    src = ROOT / "hermes-docker" / "hermes-plugins" / "barrel-heaven"
    if not src.is_dir():
        print(f"missing plugin {src}", file=sys.stderr)
        return 1
    dest = hermes_home() / "plugins" / "barrel-heaven"
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(src, dest)
    print(f"installed plugin → {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
