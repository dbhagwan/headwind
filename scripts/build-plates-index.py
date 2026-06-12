#!/usr/bin/env python3
"""Builds Headwind's bundled approach-plate index from the FAA d-TPP metafile.

Input:  d-TPP_Metafile.xml (https://aeronav.faa.gov/d-tpp/<cycle>/xml_data/)
Output: Headwind/Resources/us-plates.json
        {"cycle": "2606", "airports": {"KSFO": [{"n": name, "c": code, "p": pdf}, ...]}}

Usage: python3 scripts/build-plates-index.py /path/to/d-tpp_Metafile.xml
"""

import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def main(metafile):
    tree = ET.parse(metafile)
    root = tree.getroot()
    cycle = root.get("Cycle", "")

    airports = {}
    count = 0
    for state in root.findall("state_code"):
        for city in state.findall("city_name"):
            for airport in city.findall("airport_name"):
                ident = (airport.get("icao_ident") or "").strip() or (airport.get("apt_ident") or "").strip()
                if not ident:
                    continue
                plates = airports.setdefault(ident.upper(), [])
                for record in airport.findall("record"):
                    name = (record.findtext("chart_name") or "").strip()
                    code = (record.findtext("chart_code") or "").strip()
                    pdf = (record.findtext("pdf_name") or "").strip()
                    if not name or not pdf or pdf.upper() == "DELETED":
                        continue
                    plates.append({"n": name, "c": code, "p": pdf})
                    count += 1

    airports = {k: v for k, v in airports.items() if v}

    out = Path(__file__).resolve().parent.parent / "Headwind" / "Resources" / "us-plates.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"cycle": cycle, "airports": airports}, f, separators=(",", ":"), ensure_ascii=False)

    print(f"cycle {cycle}: {len(airports)} airports, {count} plates, {out.stat().st_size/1e6:.1f} MB")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "d-tpp_Metafile.xml")
