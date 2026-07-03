# iOS 27 Adoption Plan

iOS 27 shipped as a developer beta on June 8, 2026 (public release expected
September 2026). Headwind targets iOS 26; the plan is to **build with the
iOS 27 SDK while keeping the 26.0 deployment target**, adopting new API
behind `#available(iOS 27, *)` so iOS 26 users lose nothing.

CI already auto-selects the newest Xcode on the runner image (`sort -V`
picks an Xcode 27 beta the moment GitHub installs one); the build log's
Xcode inventory step tracks when that flips.

## Worth adopting (ranked)

1. **Resizable iPhone apps + adaptive layout APIs.** iPhone apps become
   resizable (iPhone Mirroring, iPad windows). Audit screens at arbitrary
   sizes; our `sidebarAdaptable` tabs and relative layouts should mostly
   hold. Xcode 27 previews add resize handles — use them in M2 device
   testing.
2. **`.toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)`** — let
   the nav bar tuck away while a pilot scrolls a plate or a long METAR list.
3. **`.reorderable()` on `ForEach`** — drag-to-reorder route waypoints
   without EditMode; falls back to today's `.onMove` on iOS 26.
4. **`.swipeActions()` in any scroll container** — native swipe-to-remove on
   the weather station cards (currently a menu action).
5. **Toolbar `visibilityPriority` / overflow menu** — keep the map's layer
   button visible at compact widths, overflow the rest.
6. **Liquid Glass v2** — second-iteration design tokens apply automatically
   when built with the 27 SDK. Note the new user-facing transparency
   slider: never rely on glass translucency for contrast (our badges and
   banners already use solid fills — keep it that way).
7. **`AsyncImage` HTTP-cache behavior + `ContentBuilder` compile-time wins**
   — free with the SDK bump.
8. **`WritableDocument`/`ReadableDocument`** — the right foundation for the
   1.4 document-binder feature (POH PDFs, certificates) when we build it.

## Not relevant now

Dictation, HealthKit, Metal 4.1, StoreKit updates, PlayStation controller
input, Background Assets (our data bundles are small and cycle-updated via
the repo instead).

## Sequencing

- Now: keep deployment target 26.0; land `#available(iOS 27)` conveniences
  opportunistically once CI has an Xcode 27 beta.
- After iOS 27 GA (Sept 2026) + one point release: consider raising the
  minimum only if adoption data says so — a free app should stay generous.

Sources: Apple "What's new in Xcode 27" (WWDC26 session 258),
developer.apple.com/whats-new, WWDC26 SwiftUI community breakdowns.
