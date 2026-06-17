# Headwind Product Roadmap

The thesis: a free, open-source EFB can reach ForeFlight-class capability for
the GA pilot because every load-bearing data source — airports, charts,
plates, weather, airspace, TFRs — is published free by the FAA and NOAA.
Headwind's job is great engineering and design on top of free data, with all
flight-critical math in the tested `HeadwindCore` package and AI strictly
advisory.

Sequencing logic: alternate **trust releases** (correctness, data depth) with
**capability releases** (new things the app can do), and never ship a number
a pilot could misread.

---

## Shipped (v0.1 – v0.4)

- App shell: Liquid Glass design system, sidebar-adaptable tabs, iOS/iPadOS 26
- Full US directory: 16,846 airports (runways with true headings,
  frequencies), 2,804 navaids; ranked search; nearest
- Moving map on MKMapView: clean aeronautical mode (muted base + vector
  Class B/C/D), FAA raster layers (VFR Sectional/Terminal, IFR Low/High)
  with disk cache, offline area downloads, and z12+ over-zoom
- Live TFR polygons + grouped airspace list
- Weather: METAR/TAF (live, categorized), winds aloft (full FB decoder),
  density altitude, per-runway head/crosswind advisor
- Planner: mixed airport/VOR routes, wind-triangle legs, ETE/fuel totals
- Approach plates: 24,006 d-TPP procedures, grouped per airport, PDF viewer,
  offline cache keyed by cycle
- W&B with CG envelope chart (3 sample aircraft), checklists, SwiftData
  logbook, AI briefing (on-device Apple Intelligence, grounded, with
  deterministic fallback)
- Infra: data pipelines (`build-airport-db.py`, `build-plates-index.py`),
  Linux CI for ~80 core tests, macOS CI that builds the app and commits
  simulator screenshots

---

## 1.0 — "Preflight" (ship vehicle)

Goal: a stranger downloads it and plans a VFR flight safely.

**M1 Hardening (engineering, ~1–2 wks)**
- ✅ Data-cycle automation: `data-refresh.yml` regenerates airport and plate
  bundles each cycle and opens a PR; AIRAC cycle math + currency in
  HeadwindCore; in-app staleness badge/banner; self-healing remote
  plate-index fallback when the bundle expires (cycle 2606 → 07/09/26)
- ✅ `PrivacyInfo.xcprivacy` privacy manifest
- ✅ CI triggers cover `main`
- ✅ First-launch gate: 3-page intro ending in a required not-for-navigation
  acknowledgement, gating the app before any map/data/location startup
- ✅ Planner labels courses/headings as true (°T) until WMM lands
- Offline/error audit on every screen

**M2 Device reality & beta (~3–4 wks calendar)**
- Apple Developer account; real iPhone/iPad profiling (GPS in motion,
  battery, launch decode — move bundles to SQLite if hardware says so)
- iPad layout, VoiceOver, Dynamic Type passes; MetricKit crash collection
- TestFlight closed beta with 10–20 GA pilots/CFIs, 2+ weeks

**M3 Store packaging (~1 wk)**
- Privacy policy + support page (GitHub Pages), App Privacy answers,
  listing assets (reuse the CI screenshot rig), submission buffer

---

## 1.x — Planning depth (trust releases)

**1.1 Navigation correctness**
- WMM magnetic variation → magnetic courses/headings app-wide
- Per-leg winds: interpolate the FB winds-aloft grid into each leg instead
  of one manual wind input; altitude-aware
- Climb/descent: TOC/TOD, block fuel with taxi/climb/reserve, required
  reserve warnings, alternate planning

**1.2 Full briefing parity**
- AIRMETs/SIGMETs and PIREPs (free aviationweather.gov endpoints) drawn on
  the map and in briefings
- NEXRAD radar + satellite weather map layers (free NOAA/mesonet tiles)
- NOTAMs beyond TFRs (FAA NOTAM API — requires free API key provisioning)
- Briefing screen restructured to the standard format: adverse conditions →
  synopsis → current → forecast → winds → NOTAMs; AI summary on top,
  always grounded, always labeled

**1.3 Aircraft & performance**
- User-defined aircraft (SwiftData): W&B stations/envelopes, cruise
  profiles, fuel curves
- POH performance: takeoff/landing distance vs density altitude/weight/wind
- Maintenance tracking: oil, annual, transponder/pitot-static, ELT dates

**1.4 Pilot's binder**
- Custom checklist editor with import/export
- Document binder: PDFs (POH, insurance, certificates) with iCloud Drive
- Saved routes library; named flight plans; CloudKit sync across devices

---

## 2.x — In flight (capability releases)

**2.0 Track logging**
- GPS breadcrumb recording with auto takeoff/landing detection
- Auto-filled logbook entries (times, day/night, landings) — pilot confirms
- Track replay on the map; GPX/KML export

**2.1 ADS-B In (GDL90 over UDP — Stratux, Sentry, Stratus)**
- Traffic: relative-altitude targets with trend vectors and alerting
- FIS-B in-flight weather: NEXRAD, METARs, TAFs, NOTAMs with no cell signal
- AHRS backup attitude from receiver hardware

**2.2 Terrain & safety**
- Route terrain profile (USGS/Copernicus elevation), altitude-colored
  terrain shading on the map
- FAA obstacle database (DOF) near the route
- Wind-aware glide range ring; emergency "nearest" mode with best-glide
  guidance

**2.3 Georeferenced plates & taxi**
- Ownship position drawn on approach plates and airport diagrams
  (FAA georef bounds)
- Runway awareness: "approaching RWY 28L" advisories while taxiing

---

## 3.x — Platform & intelligence

**3.1 Apple platform depth**
- Widgets (home-airport METAR, next plan), Live Activities (active leg on
  Lock Screen / Dynamic Island), StandBy instrument mode
- Apple Watch: nearest airport, METAR glance, flight timers
- Siri / App Intents: "Brief me for my flight", "Start the before-takeoff
  checklist"; iPad multi-window + external display support

**3.2 Apple Intelligence as interface (always grounded, always advisory)**
- Natural-language route entry: "Palo Alto to Tahoe at 8:30, stay out of
  the Bravo" → structured route via guided generation; numbers still come
  from HeadwindCore
- Briefing Q&A over the fetched data; plain-English NOTAM summaries
- Post-flight debrief: narrative generated from the track log
- Smart fuel-stop and alternate suggestions

**3.3 Sync & ecosystem**
- Logbook export/import: ForeFlight CSV (switcher path!), MyFlightbook,
  Garmin Pilot
- CFI digital endorsements; shared routes between pilots

---

## 4.x — Beyond the weekend pilot

- IFR tooling: airway graph routing (V/J airways), preferred/TEC routes,
  expected-route prediction; filing requires a Leidos 1800wxbrief
  partnership — flagged, not assumed
- International: Canada/Mexico data, ICAO flight-plan formats
- Mission modes: helicopter, seaplane, glider (soaring layers)
- Community chart/data mirrors to keep the $0-infrastructure promise at scale

---

## Standing principles

- Free forever for the core; all data from public FAA/NOAA sources;
  any feature requiring a paid key or partnership is flagged before design
- Flight math lives only in tested HeadwindCore; the language model never
  computes a number a pilot acts on
- Every release: Linux core tests green, macOS build green, CI screenshots
  refreshed, data bundles current
- Not-for-navigation posture until the data pipeline has cycle-currency
  guarantees end to end
