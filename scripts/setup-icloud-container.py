#!/usr/bin/env python3
"""Create iCloud.com.headwind.app and assign it to the App ID.

Container creation is absent from Apple's documented App Store Connect
API, so this walks a ladder of candidate endpoints, most-official first:

  1. api.appstoreconnect.apple.com /v1/cloudContainers (in case Apple
     shipped it quietly)
  2. developerservices2.apple.com — the provisioning service xcodebuild
     itself talks to with the same API key

Every response is logged verbatim so a failed run tells us exactly what
Apple said. Exits 0 only when the container exists AND is assigned to
the bundle ID's iCloud capability.
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
CONTAINER = "iCloud.com.headwind.app"
BUNDLE_ID = "com.headwind.app"


def token():
    return jwt.encode(
        {"iss": ISSUER, "iat": int(time.time()), "exp": int(time.time()) + 600,
         "aud": "appstoreconnect-v1"},
        P8, algorithm="ES256", headers={"kid": KEY_ID})


def call(method, url, body=None, extra_headers=None):
    headers = {"Authorization": f"Bearer {token()}", "Content-Type": "application/json"}
    headers.update(extra_headers or {})
    req = urllib.request.Request(url, method=method, headers=headers,
                                 data=json.dumps(body).encode() if body else None)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read().decode(errors="replace")
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw[:400]}
    except Exception as e:  # noqa: BLE001
        return 0, {"error": str(e)}


def log(label, status, body):
    print(f"{label}: {status} {json.dumps(body)[:500]}")


ASC = "https://api.appstoreconnect.apple.com"
DEVSVC = "https://developerservices2.apple.com/services/v1"


def find_container():
    for url in (f"{ASC}/v1/cloudContainers?filter[identifier]={CONTAINER}",
                f"{DEVSVC}/cloudContainers?filter[identifier]={CONTAINER}"):
        status, r = call("GET", url)
        log(f"GET {url}", status, r)
        if status == 200:
            for item in r.get("data", []):
                if item.get("attributes", {}).get("identifier") == CONTAINER:
                    return item["id"], url.rsplit("/cloudContainers", 1)[0]
            return None, url.rsplit("/cloudContainers", 1)[0]
    return None, None


def main():
    container_id, base = find_container()
    if container_id:
        print(f"container already exists: {container_id}")

    if not container_id:
        body = {"data": {"type": "cloudContainers",
                         "attributes": {"identifier": CONTAINER, "name": "Headwind"}}}
        for url in ([f"{base}/cloudContainers"] if base else []) + \
                   [f"{ASC}/v1/cloudContainers", f"{DEVSVC}/cloudContainers"]:
            status, r = call("POST", url, body)
            log(f"POST {url}", status, r)
            if status in (200, 201):
                container_id = r["data"]["id"]
                base = url.rsplit("/cloudContainers", 1)[0]
                break
        # developerservices2 sometimes wants the teamId inline
        if not container_id:
            status, r = call("POST", f"{DEVSVC}/cloudContainers",
                             {"data": {"type": "cloudContainers",
                                       "attributes": {"identifier": CONTAINER,
                                                      "name": "Headwind",
                                                      "teamId": os.environ.get("APPLE_TEAM_ID", "")}}})
            log("POST devsvc with teamId", status, r)
            if status in (200, 201):
                container_id = r["data"]["id"]
                base = DEVSVC

    if not container_id:
        sys.exit("FAILED: no endpoint would create the container")

    # Assign to the bundle ID's ICLOUD capability.
    status, r = call("GET", f"{ASC}/v1/bundleIds?filter[identifier]={BUNDLE_ID}")
    bid = r["data"][0]["id"]
    status, r = call("GET", f"{ASC}/v1/bundleIds/{bid}/bundleIdCapabilities?limit=50")
    cap_id = next((c["id"] for c in r.get("data", [])
                   if c["attributes"].get("capabilityType") == "ICLOUD"), None)
    print(f"bundleId {bid}, ICLOUD capability {cap_id}")

    rel = {"cloudContainers": {"data": [{"type": "cloudContainers", "id": container_id}]}}
    attempts = [
        ("PATCH", f"{ASC}/v1/bundleIdCapabilities/{cap_id}",
         {"data": {"type": "bundleIdCapabilities", "id": cap_id,
                   "attributes": {"capabilityType": "ICLOUD"},
                   "relationships": rel}}),
        ("PATCH", f"{DEVSVC}/bundleIdCapabilities/{cap_id}",
         {"data": {"type": "bundleIdCapabilities", "id": cap_id,
                   "attributes": {"capabilityType": "ICLOUD"},
                   "relationships": rel}}),
        ("POST", f"{DEVSVC}/bundleIdCapabilities",
         {"data": {"type": "bundleIdCapabilities",
                   "attributes": {"capabilityType": "ICLOUD"},
                   "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid}},
                                     **rel}}}),
    ]
    for method, url, body in attempts:
        status, r = call(method, url, body)
        log(f"{method} {url}", status, r)
        if status in (200, 201, 204):
            print("ASSIGNED — container linked to App ID")
            return

    sys.exit("FAILED: container exists but could not be assigned to the App ID")


if __name__ == "__main__":
    main()
