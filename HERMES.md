# Hermes — Birddog Softworks / Barrel Heaven

Island from the LAD profile. Game: **Barrel Heaven**. Studio: **Birddog Softworks**.

## One-time

1. Ollama running (`ollama.exe`). Models: `qwen3:32b`, `qwen2.5:72b`, `qwen2.5:32b`.
2. Copy `XAI_API_KEY` into the profile env (do not commit it):

```
powershell -File hermes-docker\setup-profile.ps1
```

3. Restart Hermes / OpenCode after config changes.

## Run

```
hermes -p barrel-heaven
```

CWD is `C:/Workspace/barrel-heaven/godot`. Inference: **xAI grok-4.6** primary, **Ollama** fallback. OpenRouter is not used.

Dashboard: http://127.0.0.1:9119/login — user `barrel`, password `heaven`.
Board slug: `barrel-heaven`. Seed: `powershell -File tools\hermes-setup.ps1`
If `/` 500s on `provider=basic`, use `/login`. Recreate with `hermes-docker/recreate-studio.ps1`.

## OpenCode

Project `opencode.json` enables only `xai` and `ollama`. Default model `xai/grok-4.6`, small model `ollama/qwen2.5:32b`.
