#!/usr/bin/env python3
from pathlib import Path

p = Path("/opt/hermes/hermes_cli/dashboard_auth/middleware.py")
text = p.read_text()
needle = "    provider = providers[0]\n    prefix = prefix_from_request(request)\n"
insert = (
    "    provider = providers[0]\n"
    "    if getattr(provider, \"supports_password\", False):\n"
    "        return None\n"
    "    prefix = prefix_from_request(request)\n"
)
if "if getattr(provider, \"supports_password\", False):" in text:
    print("sso patch already applied")
else:
    if needle not in text:
        raise SystemExit("middleware.py marker not found")
    p.write_text(text.replace(needle, insert, 1))
    print("patched auto-sso skip for password providers")
