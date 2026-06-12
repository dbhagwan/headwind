# Roadmap to ForeFlight-class parity

## v0.1 — Foundation (this release)
- App shell, Liquid Glass design system, sidebar-adaptable tabs
- Moving map with ownship, route overlay, category-colored airports
- Live METAR/TAF, flight categories, favorites
- Route planner with wind triangle, ETE/fuel totals
- AI briefing (Apple Intelligence, grounded + fallback)
- Weight & balance with CG envelope chart
- Checklists, SwiftData logbook
- HeadwindCore tested in Linux CI

## v0.2 — Real data at scale ✅ (this release)
- FAA NASR / OurAirports import pipeline (all open US airports, runways with
  true headings, frequencies, navaids) — `scripts/build-airport-db.py`
- Async-loaded in-memory directory; zoom-aware map layering
- Navaids as route waypoints (VOR/NDB idents resolve in the planner)
- Winds aloft: FB product fetch + full decoder, region viewer
- Density altitude and per-runway head/crosswind advisor on airport pages
- Multiple aircraft W&B profiles

## v0.2.x — Data depth (next)
- On-device SQLite/GRDB store with incremental NASR cycle updates
- Magnetic variation model (WMM) for magnetic courses/headings
- NOTAMs via FAA NOTAM API (requires API key provisioning)
- Per-leg winds interpolation from the FB grid into the planner

## v0.3 — Charts
- FAA VFR sectional/TAC raster tiles as MapKit overlay (offline tile cache)
- IFR low/high enroute charts
- Geo-referenced approach plates (FAA d-TPP), organized by airport
- Document binder (POH, certificates) with iCloud sync

## v0.4 — In-flight
- ADS-B In traffic & FIS-B weather via GDL90 over UDP (Stratux/Sentry/Stratus)
- Terrain awareness: profile view + altitude-colored terrain shading
- Glide range ring, nearest-airport emergency mode
- Track logging with breadcrumb replay and logbook auto-fill

## v0.5 — Intelligence & polish
- Apple Intelligence route insights (alternates, fuel stops) — advisory only
- App Intents + Siri ("Brief me for the flight to Tahoe")
- Live Activities for active flight plans; StandBy instrument mode
- iPad multi-window, pointer/keyboard shortcuts, widgets

## Quality bars
- Every release: HeadwindCore coverage stays green on Linux CI
- macOS CI job with `xcodebuild test` once a hosted iOS 26 runner image is available
- Accessibility audit (VoiceOver, Dynamic Type) before any App Store release
