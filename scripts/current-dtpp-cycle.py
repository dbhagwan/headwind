#!/usr/bin/env python3
"""Prints the d-TPP cycle label that is currently effective.

Uses the same 28-day AIRAC grid as HeadwindCore (anchor: cycle 2606 effective
2026-06-11), then verifies the metafile is published, falling back one cycle
if the current one isn't up yet. Label goes to stdout; logs to stderr.
"""

import datetime
import sys
import urllib.request

ANCHOR = datetime.date(2026, 6, 11)
PERIOD = 28


def effective_on_or_before(day):
    steps = (day - ANCHOR).days // PERIOD  # Python // floors toward -inf
    return ANCHOR + datetime.timedelta(days=steps * PERIOD)


def label_for(effective):
    year = effective.year
    first = effective
    while (first - datetime.timedelta(days=PERIOD)).year == year:
        first -= datetime.timedelta(days=PERIOD)
    n = (effective - first).days // PERIOD + 1
    return f"{year % 100:02d}{n:02d}"


def metafile_url(label):
    return f"https://aeronav.faa.gov/d-tpp/{label}/xml_data/d-tpp_Metafile.xml"


def is_published(label):
    req = urllib.request.Request(metafile_url(label), method="HEAD")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status == 200
    except Exception as exc:  # noqa: BLE001
        print(f"  {label}: {exc}", file=sys.stderr)
        return False


def main():
    today = datetime.date.today()
    effective = effective_on_or_before(today)
    for _ in range(2):
        label = label_for(effective)
        print(f"checking cycle {label} (effective {effective})", file=sys.stderr)
        if is_published(label):
            print(label)
            return
        effective -= datetime.timedelta(days=PERIOD)
    sys.exit("No published d-TPP cycle found")


if __name__ == "__main__":
    main()
