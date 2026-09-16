#!/usr/bin/env python3
from pathlib import Path
import sys

path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("drivers/cpufreq/mediatek-cpufreq-hw.c")
reference = Path(__file__).with_name("mediatek-cpufreq-hw.2cluster-a76scale.c")

if not path.exists():
    raise SystemExit(f"dual-domain: target driver not found: {path}")
if not reference.exists():
    raise SystemExit(f"dual-domain: canonical driver not found: {reference}")

path.write_text(reference.read_text())
print(f"dual-domain: installed 2-cluster common 725-2200 logical-scale driver at {path}")
