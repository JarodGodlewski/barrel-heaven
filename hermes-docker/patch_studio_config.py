#!/usr/bin/env python3
from pathlib import Path
import os
import yaml

cfg_path = Path("/opt/data/config.yaml")
env_path = Path("/opt/data/.env")

data = {}
if cfg_path.exists():
    data = yaml.safe_load(cfg_path.read_text()) or {}

data.setdefault("model", {})
data["model"]["provider"] = "xai"
data["model"]["default"] = "grok-4.6"
data["model"]["base_url"] = "https://api.x.ai/v1"
data.setdefault("terminal", {})
data["terminal"]["cwd"] = "/workspace/barrel-heaven/godot"
data["terminal"]["backend"] = "local"
data.setdefault("kanban", {})
data["kanban"]["default_board"] = "barrel-heaven"
data["fallback_providers"] = [
    {
        "provider": "ollama",
        "model": "qwen3:32b",
        "base_url": "http://host.docker.internal:11434/v1",
    },
    {
        "provider": "ollama",
        "model": "qwen2.5:32b",
        "base_url": "http://host.docker.internal:11434/v1",
    },
]
cfg_path.write_text(yaml.safe_dump(data, sort_keys=False))

xai = os.environ.get("XAI_API_KEY", "")
lines = []
if env_path.exists():
    for line in env_path.read_text().splitlines():
        if line.startswith("OPENROUTER_API_KEY="):
            continue
        if line.startswith("XAI_API_KEY="):
            continue
        lines.append(line)
if xai:
    lines.append("XAI_API_KEY=" + xai)
env_path.write_text("\n".join(lines) + "\n")
print("patched config.yaml model=xai/grok-4.6 cwd=/workspace/barrel-heaven/godot")
