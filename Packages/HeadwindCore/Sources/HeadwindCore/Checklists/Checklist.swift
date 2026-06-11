import Foundation

public struct ChecklistItem: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    /// The challenge, e.g. "Mixture".
    public let challenge: String
    /// The response, e.g. "RICH".
    public let response: String

    public init(id: UUID = UUID(), challenge: String, response: String) {
        self.id = id
        self.challenge = challenge
        self.response = response
    }
}

public struct Checklist: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    /// Phase of flight, e.g. "Preflight", "Before Takeoff", "Emergency".
    public let phase: String
    public let isEmergency: Bool
    public let items: [ChecklistItem]

    public init(id: UUID = UUID(), title: String, phase: String, isEmergency: Bool = false, items: [ChecklistItem]) {
        self.id = id
        self.title = title
        self.phase = phase
        self.isEmergency = isEmergency
        self.items = items
    }
}
