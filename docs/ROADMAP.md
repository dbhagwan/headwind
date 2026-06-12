# Roadmap to ForeFlight-class parity

## Path to 1.0 (shippable on the App Store)

### M1 — Hardening (engineering, ~1–2 weeks)
Blockers that are pure code:
- **Data-cycle automation.** Bundled FAA data goes stale on fixed clocks:
  airports/navaids on the 28-day NASR cycle, plates on the 28-day d-TPP
  cycle (current bundle: 2606, expires 07/09/26 — after that the PDF URLs
  break). Add: scheduled GitHub Action that regenerates both bundles and
  opens a PR each cycle; in-app effective-date check that warns when data
  is stale and falls back to fetching the current plate index remotely.
- **Privacy manifest** (`PrivacyInfo.xcprivacy`) — required for App Store
  submission (UserDefaults et al. are "required-reason" APIs).
- **First-launch gate**: not-for-navigation acknowledgement + location
  permission pre-prompt + 3-screen feature intro.
- **True-vs-magnetic honesty pass**: every heading/course in the UI gets an
  explicit °T label until WMM lands (pilots fly magnetic; silent true
  headings are a correctness issue).
- **Offline/error audit**: every screen must degrade gracefully with no
  network (weather shows age-labeled cache, tiles serve disk, plates show
  the offline copy or a clear error).
- Point `screenshots.yml`/`ci.yml` triggers at `main`.

### M2 — Device reality & beta (calendar, ~3–4 weeks)
The app has only ever run in CI simulators:
- Apple Developer account; run on real iPhone + iPad: GPS in motion,
  memory with the full database, battery on a 2-hour map session, launch
  time (5.6 MB + 1.4 MB JSON decodes — move to SQLite if slow on hardware).
- iPad layout pass (sidebar, multitasking, pointer/keyboard).
- Accessibility: VoiceOver labels for markers/instruments, Dynamic Type.
- MetricKit crash/hang collection (no third-party analytics).
- **TestFlight closed beta with 10–20 real GA pilots/CFIs**, two weeks
  minimum — they will find the workflow truths no simulator run can.

### M3 — Store packaging (~1 week)
- Privacy policy + support page (GitHub Pages), App Privacy questionnaire
  (location: used, not linked, no tracking).
- Listing: description, keywords, screenshots (reuse the CI capture rig),
  preview video optional.
- Submission with review-rejection buffer; aviation apps clear review
  routinely with clear disclaimers.

### Post-1.0
- Magnetic variation (WMM) → magnetic courses/headings everywhere
- NOTAMs (FAA NOTAM API key) beyond TFRs
- ADS-B In via GDL90 (Stratux/Sentry): traffic + FIS-B weather in flight
- GPS track logging with logbook auto-fill and breadcrumb replay
- Widgets (home-airport METAR), Live Activities (active leg), Siri/App
  Intents, natural-language route entry via Apple Intelligence
- Terrain awareness, glide ring, georeferenced ownship on plates

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

## v0.3 — Charts & airspace ✅ (this release)
- FAA VFR sectional/terminal + IFR low/high raster layers (FAA public
  tile service) with disk cache and offline area downloads
- Live TFR polygons on the map + grouped airspace list (tfr.faa.gov)

## v0.3.x — Charts depth (next)
- Geo-referenced approach plates (FAA d-TPP), organized by airport
- Document binder (POH, certificates) with iCloud sync
- Chart currency tracking against the 56-day chart cycle

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
