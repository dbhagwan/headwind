#!/usr/bin/env python3
"""Ensure the App ID carries the capabilities the entitlements need.

Cloud-managed signing (xcodebuild -allowProvisioningUpdates) regenerates
provisioning profiles but does not reliably ADD capabilities to the App
ID from CI. This runs before archiving: it enables iCloud (CloudKit) and
Push Notifications on the bundle ID via the App Store Connect API if
they're missing. Idempotent — a no-op when already enabled.

Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (key contents), BUNDLE_ID.
"""

import json
import os
import sys
import time
import urllib.request

import jwt

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
P8 = os.environ["ASC_KEY_P8"]
BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.headwind.app")

WANTED = {
    "ICLOUD": [{"key": "ICLOUD_VERSION", "options": [{"key": "XCODE_6"}]}],
    "PUSH_NOTIFICATIONS": None,
}


def call(method, path, body=None):
    token = jwt.encode(
        {"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 600,
         "aud": "appstoreconnect-v1"},
        P8, algorithm="ES256", headers={"kid": KEY_ID})
    req = urllib.request.Request(
        f"https://api.appstoreconnect.apple.com{path}", method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        data=json.dumps(body).encode() if body else None)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")


def main():
    status, r = call("GET", f"/v1/bundleIds?filter[identifier]={BUNDLE_ID}")
    if status != 200 or not r.get("data"):
        sys.exit(f"bundle ID lookup failed: {status} {r}")
    bid = r["data"][0]["id"]

    _, caps = call("GET", f"/v1/bundleIds/{bid}/bundleIdCapabilities?limit=50")
    have = {c["attributes"].get("capabilityType") for c in caps.get("data", [])}
    print(f"{BUNDLE_ID}: existing capabilities {sorted(have) or '(none)'}")

    failed = False
    for cap, settings in WANTED.items():
        if cap in have:
            print(f"  {cap}: already enabled")
            continue
        attrs = {"capabilityType": cap}
        if settings:
            attrs["settings"] = settings
        status, r = call("POST", "/v1/bundleIdCapabilities", {
            "data": {"type": "bundleIdCapabilities", "attributes": attrs,
                     "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid}}}}})
        ok = status in (200, 201)
        detail = "" if ok else f" {status} {json.dumps(r)[:300]}"
        print(f"  {cap}: {'enabled' if ok else 'FAILED' + detail}")
        failed |= not ok
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
