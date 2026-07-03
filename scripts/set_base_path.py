"""Set [deploy].base_path in a kura.toml to the value in the KURA_BP env var.

Usage: KURA_BP="/foo" python3 set_base_path.py path/to/kura.toml

Replaces base_path inside the [deploy] table (adding it if the table lacks one, or creating the
table if it is absent). The top-level content base_path and every other line are left untouched.
"""

import os
import re
import sys
import pathlib

bp = os.environ["KURA_BP"]
path = pathlib.Path(sys.argv[1])
lines = path.read_text().splitlines()

out: list[str] = []
in_deploy = False
done = False
for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        if in_deploy and not done:
            out.append(f'base_path = "{bp}"')
            done = True
        in_deploy = stripped == "[deploy]"
        out.append(line)
        continue
    if in_deploy and re.match(r"\s*base_path\s*=", line):
        out.append(f'base_path = "{bp}"')
        done = True
        continue
    out.append(line)

if in_deploy and not done:
    out.append(f'base_path = "{bp}"')
    done = True
if not done:
    out += ["", "[deploy]", 'target = "github-pages"', f'base_path = "{bp}"']

path.write_text("\n".join(out) + "\n")
