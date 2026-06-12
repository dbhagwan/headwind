# Headwind Architecture

## Layering

```
┌────────────────────────────────────────────┐
│ Headwind (app target, iOS/iPadOS 26)       │
│  SwiftUI screens · MapKit · Swift Charts   │
│  SwiftData (logbook) · FoundationModels    │
│  Services: WeatherService, LocationService │
│            AirportStore, PlanStore,        │
│            BriefingService                 │
├────────────────────────────────────────────┤
│ HeadwindCore (Swift package, Foundation    │
│ only — builds and tests on Linux)          │
│  NavMath · WindTriangle · LegCalculator    │
│  Metar/TAF models · FlightCategory         │
│  AirportDatabase · WeightBalance           │
│  Checklist models · MetarSummarizer        │
└────────────────────────────────────────────┘
```

**Rule:** everything that can be expressed without UIKit/SwiftUI/CoreLocation
goes in `HeadwindCore`. The package defines its own `Coordinate` type; the app
bridges it to `CLLocationCoordinate2D` in one extension. This keeps the
flight-critical math deterministic, dependency-free, and continuously tested
in CI without a macOS runner.

## App layer conventions

- **State:** `@Observable` service classes injected via `.environment(...)`
  from `HeadwindApp`. SwiftData is used only where durable user data lives
  (logbook today; aircraft profiles and custom checklists next).
- **Design system:** `DesignSystem/HWTheme.swift` centralizes the Liquid Glass
  card treatment (`.hwGlassCard()`), flight-category colors, and instrument
  readouts. Screens never call `.glassEffect` ad hoc except for genuinely
  bespoke surfaces (map controls).
- **Navigation:** one `NavigationStack` per tab; `Tab(role: .search)` hosts
  airport search so it adapts to the iPadOS sidebar layout via
  `.tabViewStyle(.sidebarAdaptable)`.

## Data sources

| Data | Source | Notes |
| --- | --- | --- |
| METAR / TAF | `aviationweather.gov/api/data` | Free, no key. Decoder is tolerant of mixed types (`"VRB"`, `"10+"`). |
| Winds aloft | `aviationweather.gov/api/data/windtemp` | FB text product; full decoder (high-speed encoding, implicit negative temps) in `WindsAloftParser`. |
| Airports & navaids | Bundled `us-airports.json` / `us-navaids.json` | Generated from FAA data via OurAirports by `scripts/build-airport-db.py` (16.8k airports, 2.8k navaids). Decoded off-main at launch; the map queries by region + kind. |
| AI briefings | On-device FoundationModels | Prompt is grounded in raw METARs; deterministic `MetarSummarizer` is the universal fallback and the grounding text. |

## Safety posture

Aviation apps carry real risk. Hard rules baked into the design:

1. Computed values (headings, fuel, CG) come only from tested `HeadwindCore`
   code — never from the language model.
2. AI output is summarization of supplied observations only, always labeled,
   and always ends with a "not an official briefing" reminder.
3. Sample data (airports, aircraft profiles, checklists) is labeled as such in
   the UI and the About screen carries the not-for-navigation disclaimer.
