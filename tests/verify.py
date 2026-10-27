#!/usr/bin/env python3
"""Run real Godot checks; fail on engine errors even when Godot exits zero."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

PROJECT = Path(__file__).resolve().parent.parent
EVIDENCE = PROJECT / "evidence"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=shutil.which("godot") or shutil.which("godot4"))
    parser.add_argument("--render", action="store_true", help="Also run GPU screenshots; needs a display")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Pass --godot /path/to/Godot")
    EVIDENCE.mkdir(exist_ok=True)
    steps = [
        ("import", ["--headless", "--editor", "--quit"]),
        ("acceptance", ["--headless", "--fixed-fps", "60", "--script", "res://tests/acceptance.gd"]),
        ("input-smoke", ["--headless", "--fixed-fps", "60", "--script", "res://tests/input_smoke.gd"]),
    ]
    if args.render:
        steps += [
            ("rendered", ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--fixed-fps", "60", "--script", "res://tests/acceptance.gd", "--", "--capture"]),
            ("portraits", ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--script", "res://tests/portraits.gd"]),
        ]
    receipt = {"commands": [], "production_objective_scan": None}
    for name, flags in steps:
        command = [args.godot, "--path", str(PROJECT), *flags]
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        output = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout)
        (EVIDENCE / f"{name}.log").write_text(output)
        errors = [line for line in output.splitlines() if re.search(r"(?:SCRIPT ERROR|^ERROR:|^WARNING:|Parse Error:)", line)]
        receipt["commands"].append({"name": name, "argv": command, "exit_code": result.returncode, "errors_or_warnings": errors})
        print(f"{name}: exit={result.returncode}; engine errors/warnings={len(errors)}", flush=True)
        for line in output.splitlines():
            if "VERDICT" in line or line.startswith(("FAIL ", "CAPTURE ")):
                print(line, flush=True)
        if result.returncode or errors:
            print(output, file=sys.stderr)
            (EVIDENCE / "verification.json").write_text(json.dumps(receipt, indent=2))
            return 1
    obsolete = re.compile(r"\bfind\s+erik\b|hitta\s+erik|prata\s+med\s+erik|erikmark", re.I)
    violations = [str(p.relative_to(PROJECT)) for p in (PROJECT / "scripts").glob("*.gd") if obsolete.search(p.read_text())]
    receipt["production_objective_scan"] = {"passed": not violations, "violations": violations}
    archive = Path("/home/swirky/Downloads/dale420-garage-wars-alpha01.zip")
    if archive.exists():
        receipt["preserved_alpha_archive"] = {"path": str(archive), "sha256": hashlib.sha256(archive.read_bytes()).hexdigest()}
    receipt["passed"] = not violations
    (EVIDENCE / "verification.json").write_text(json.dumps(receipt, indent=2))
    print(f"Production objective scan: {'PASS' if not violations else 'FAIL'}")
    return int(bool(violations))


if __name__ == "__main__":
    sys.exit(main())
