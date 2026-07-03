# Headwind TestFlight Beta Plan

## Goal

Two weeks, 10–20 real GA pilots/CFIs, answering one question: **would you
preflight with this instead of ForeFlight for a weekend VFR hop?** Secondary:
find the workflow breaks no simulator run can.

## Recruiting (owner does this)

- Local flying club / FBO bulletin boards and Slack/Discords
- r/flying and r/aviation "free open-source EFB beta" post (mods usually
  allow with a no-strings framing)
- CFIs at the home field — one CFI brings 5 students
- Ask each tester: certificate level, typical aircraft, current EFB

## Build checklist (before first invite)

- [ ] Archive with Release config, upload via Xcode Organizer
- [ ] TestFlight "What to Test" filled from the script below
- [ ] Beta App Review information (same not-for-navigation notes as the
      App Review notes in app-store-listing.md)
- [ ] Crash/MetricKit collection verified on the internal build first

## Test script (paste into TestFlight "What to Test")

1. Plan tomorrow's $100-hamburger flight: your home field to a lunch stop.
   Enter the route, set your aircraft numbers, turn on winds-aloft. Do the
   numbers match what you'd compute? (MC/MH are magnetic, WMM-2025.)
2. Check weather: your field, destination, and one alternate. Compare the
   METARs/TAFs against your usual source. Try the AI briefing — is it
   accurate to the raw data? Anything it said that the METARs don't support?
3. Charts: turn on the sectional over your home airspace. Anything missing,
   misplaced, or unreadable? Download your area for offline, then airplane-
   mode the device and pan around.
4. Plates: open the plates for your home field. Correct and current?
5. Weight & balance: load your usual configuration. Does the envelope match
   your POH?
6. Airspace: do the Class B/C/D rings match the sectional? Any TFR you know
   about missing?
7. Break it: rotate, background it mid-download, kill connectivity mid-
   refresh, fat-finger the route field.

## What we measure

- Sessions that complete a full plan (route + weather + fuel check)
- Crash-free rate (MetricKit)
- The free-text answer to the one question above

## Exit criteria for submitting 1.0

- ≥ 80% of testers complete the script without a blocking bug
- Zero data-correctness reports (wrong frequency, wrong plate, wrong math)
  — any one of these blocks launch until fixed and re-verified
- Crash-free ≥ 99.5%
