#!/usr/bin/env python3
"""Builds Headwind's bundled aviation database from OurAirports CSVs.

OurAirports data is public domain and sourced from the FAA NASR cycle for US
fields. Inputs (download from https://davidmegginson.github.io/ourairports-data/):
  airports.csv, runways.csv, airport-frequencies.csv, navaids.csv

Outputs (compact JSON matching HeadwindCore's Codable models):
  Headwind/Resources/us-airports.json
  Headwind/Resources/us-navaids.json

Usage: python3 scripts/build-airport-db.py <csv-dir>
"""

import csv
import json
import sys
from collections import defaultdict
from pathlib import Path

AIRPORT_TYPES = {
    "large_airport": "large",
    "medium_airport": "medium",
    "small_airport": "small",
    "seaplane_base": "seaplane",
}

NAVAID_TYPES = {"VOR", "VOR-DME", "VORTAC", "NDB", "NDB-DME", "DME", "TACAN"}

SURFACES = {
    "ASP": "Asphalt", "ASPH": "Asphalt", "ASPHALT": "Asphalt",
    "CON": "Concrete", "CONC": "Concrete", "CONCRETE": "Concrete", "PEM": "Concrete",
    "TURF": "Turf", "GRS": "Turf", "GRASS": "Turf", "SOD": "Turf",
    "GRVL": "Gravel", "GRAVEL": "Gravel", "GRV": "Gravel",
    "DIRT": "Dirt", "EARTH": "Dirt",
    "WATER": "Water", "SAND": "Sand", "SNOW": "Snow", "ICE": "Ice",
    "MATS": "Mats", "WOOD": "Wood",
}

FREQ_NAMES = {
    "TWR": "Tower", "GND": "Ground", "ATIS": "ATIS", "CTAF": "CTAF",
    "UNIC": "UNICOM", "UNICOM": "UNICOM", "APP": "Approach", "DEP": "Departure",
    "CLD": "Clearance", "DEL": "Clearance", "AWOS": "AWOS", "ASOS": "ASOS",
    "AFIS": "AFIS", "RDO": "Radio", "FSS": "FSS", "EMERG": "Emergency",
    "A/D": "App/Dep", "ARTC": "Center", "CNTR": "Center",
}

FREQ_PRIORITY = ["ATIS", "AWOS", "ASOS", "CTAF", "UNICOM", "Ground", "Tower",
                 "Clearance", "Approach", "Departure", "App/Dep", "Center"]
MAX_FREQS = 10


def norm_surface(raw):
    raw = (raw or "").strip().upper()
    if not raw:
        return "Unknown"
    for key, value in SURFACES.items():
        if raw == key or raw.startswith(key):
            return value
    return raw.title()[:16]


def to_int(value):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return None


def to_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def main(csv_dir):
    csv_dir = Path(csv_dir)
    out_dir = Path(__file__).resolve().parent.parent / "Headwind" / "Resources"

    runways = defaultdict(list)
    with open(csv_dir / "runways.csv", newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row.get("closed") == "1":
                continue
            length = to_int(row.get("length_ft"))
            le, he = row.get("le_ident", "").strip(), row.get("he_ident", "").strip()
            if not length or length <= 0 or not le:
                continue
            runway = {
                "ident": f"{le}/{he}" if he else le,
                "lengthFt": length,
                "surface": norm_surface(row.get("surface")),
            }
            width = to_int(row.get("width_ft"))
            if width:
                runway["widthFt"] = width
            le_hdg = to_float(row.get("le_heading_degT"))
            he_hdg = to_float(row.get("he_heading_degT"))
            if le_hdg is not None:
                runway["leIdent"] = le
                runway["leHeadingDegT"] = round(le_hdg, 1)
            if he_hdg is not None and he:
                runway["heIdent"] = he
                runway["heHeadingDegT"] = round(he_hdg, 1)
            runways[row["airport_ident"]].append(runway)

    freqs = defaultdict(list)
    with open(csv_dir / "airport-frequencies.csv", newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            mhz = to_float(row.get("frequency_mhz"))
            if not mhz:
                continue
            ftype = (row.get("type") or "").strip().upper()
            name = FREQ_NAMES.get(ftype, ftype.title() or "Radio")
            freqs[row["airport_ident"]].append({"name": name, "mhz": round(mhz, 3)})

    airports = []
    seen = set()
    with open(csv_dir / "airports.csv", newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            kind = AIRPORT_TYPES.get(row.get("type"))
            if not kind or row.get("iso_country") != "US":
                continue
            ident = (row.get("icao_code") or row.get("gps_code")
                     or row.get("local_code") or row.get("ident") or "").strip().upper()
            lat, lon = to_float(row.get("latitude_deg")), to_float(row.get("longitude_deg"))
            if not ident or ident in seen or lat is None or lon is None:
                continue
            seen.add(ident)

            key = row["ident"]
            airport_freqs = sorted(
                freqs.get(key, []),
                key=lambda fr: FREQ_PRIORITY.index(fr["name"]) if fr["name"] in FREQ_PRIORITY else 99,
            )[:MAX_FREQS]

            airport = {
                "ident": ident,
                "name": (row.get("name") or ident).strip(),
                "city": (row.get("municipality") or "").strip(),
                "state": (row.get("iso_region") or "US-").split("-", 1)[-1],
                "coordinate": {"latitude": round(lat, 4), "longitude": round(lon, 4)},
                "elevationFt": to_int(row.get("elevation_ft")) or 0,
                "kind": kind,
                "runways": runways.get(key, []),
                "frequencies": airport_freqs,
            }
            iata = (row.get("iata_code") or "").strip().upper()
            if iata:
                airport["iata"] = iata
            airports.append(airport)

    navaids = []
    with open(csv_dir / "navaids.csv", newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row.get("iso_country") != "US" or row.get("type") not in NAVAID_TYPES:
                continue
            lat, lon = to_float(row.get("latitude_deg")), to_float(row.get("longitude_deg"))
            ident = (row.get("ident") or "").strip().upper()
            if not ident or lat is None or lon is None:
                continue
            navaid = {
                "ident": ident,
                "name": (row.get("name") or ident).strip(),
                "type": row["type"],
                "coordinate": {"latitude": round(lat, 4), "longitude": round(lon, 4)},
            }
            khz = to_int(row.get("frequency_khz"))
            if khz:
                navaid["frequencyKhz"] = khz
            navaids.append(navaid)

    airports.sort(key=lambda a: a["ident"])
    navaids.sort(key=lambda n: (n["ident"], n["type"]))

    out_dir.mkdir(parents=True, exist_ok=True)
    with open(out_dir / "us-airports.json", "w", encoding="utf-8") as f:
        json.dump(airports, f, separators=(",", ":"), ensure_ascii=False)
    with open(out_dir / "us-navaids.json", "w", encoding="utf-8") as f:
        json.dump(navaids, f, separators=(",", ":"), ensure_ascii=False)

    by_kind = defaultdict(int)
    for a in airports:
        by_kind[a["kind"]] += 1
    print(f"airports: {len(airports)} {dict(by_kind)}")
    print(f"navaids:  {len(navaids)}")
    for name in ("us-airports.json", "us-navaids.json"):
        print(f"{name}: {(out_dir / name).stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
