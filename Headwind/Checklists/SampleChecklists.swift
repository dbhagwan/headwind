import Foundation
import HeadwindCore

/// Built-in demo checklists. The roadmap adds user-editable checklists with
/// import/export.
enum SampleChecklists {
    static let all: [Checklist] = [
        Checklist(title: "Preflight Inspection", phase: "Ground", items: [
            ChecklistItem(challenge: "Documents (ARROW)", response: "ON BOARD"),
            ChecklistItem(challenge: "Control wheel lock", response: "REMOVE"),
            ChecklistItem(challenge: "Master switch", response: "ON"),
            ChecklistItem(challenge: "Fuel quantity", response: "CHECK"),
            ChecklistItem(challenge: "Flaps", response: "EXTEND"),
            ChecklistItem(challenge: "Master switch", response: "OFF"),
            ChecklistItem(challenge: "Fuel sumps", response: "DRAIN & CHECK"),
            ChecklistItem(challenge: "Oil level", response: "CHECK"),
            ChecklistItem(challenge: "Walkaround", response: "COMPLETE"),
        ]),
        Checklist(title: "Before Takeoff", phase: "Ground", items: [
            ChecklistItem(challenge: "Parking brake", response: "SET"),
            ChecklistItem(challenge: "Flight controls", response: "FREE & CORRECT"),
            ChecklistItem(challenge: "Flight instruments", response: "SET"),
            ChecklistItem(challenge: "Fuel selector", response: "BOTH"),
            ChecklistItem(challenge: "Mixture", response: "RICH"),
            ChecklistItem(challenge: "Run-up 1800 RPM", response: "MAGS & CARB HEAT CHECK"),
            ChecklistItem(challenge: "Trim", response: "TAKEOFF"),
            ChecklistItem(challenge: "Doors and windows", response: "LOCKED"),
            ChecklistItem(challenge: "Transponder", response: "ALT"),
        ]),
        Checklist(title: "Cruise", phase: "In Flight", items: [
            ChecklistItem(challenge: "Power", response: "SET"),
            ChecklistItem(challenge: "Mixture", response: "LEAN"),
            ChecklistItem(challenge: "Engine instruments", response: "MONITOR"),
        ]),
        Checklist(title: "Before Landing", phase: "In Flight", items: [
            ChecklistItem(challenge: "Seatbelts", response: "SECURE"),
            ChecklistItem(challenge: "Fuel selector", response: "BOTH"),
            ChecklistItem(challenge: "Mixture", response: "RICH"),
            ChecklistItem(challenge: "Carb heat", response: "AS REQUIRED"),
            ChecklistItem(challenge: "Landing light", response: "ON"),
        ]),
        Checklist(title: "Engine Failure In Flight", phase: "Emergency", isEmergency: true, items: [
            ChecklistItem(challenge: "Airspeed", response: "BEST GLIDE"),
            ChecklistItem(challenge: "Landing site", response: "SELECT"),
            ChecklistItem(challenge: "Fuel selector", response: "BOTH"),
            ChecklistItem(challenge: "Mixture", response: "RICH"),
            ChecklistItem(challenge: "Carb heat", response: "ON"),
            ChecklistItem(challenge: "Ignition", response: "BOTH / START"),
            ChecklistItem(challenge: "If no restart — Squawk", response: "7700"),
            ChecklistItem(challenge: "Radio", response: "MAYDAY 121.5"),
        ]),
    ]
}
