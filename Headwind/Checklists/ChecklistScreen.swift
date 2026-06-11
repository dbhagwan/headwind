import SwiftUI
import HeadwindCore

struct ChecklistScreen: View {
    private var phases: [(phase: String, lists: [Checklist])] {
        let grouped = Dictionary(grouping: SampleChecklists.all, by: \.phase)
        return ["Ground", "In Flight", "Emergency"].compactMap { phase in
            grouped[phase].map { (phase, $0) }
        }
    }

    var body: some View {
        List {
            ForEach(phases, id: \.phase) { group in
                Section(group.phase) {
                    ForEach(group.lists) { checklist in
                        NavigationLink(value: checklist) {
                            HStack {
                                Image(systemName: checklist.isEmergency ? "exclamationmark.triangle.fill" : "checklist")
                                    .foregroundStyle(checklist.isEmergency ? .red : .accentColor)
                                Text(checklist.title)
                                Spacer()
                                Text("\(checklist.items.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Checklists")
        .navigationDestination(for: Checklist.self) { checklist in
            ChecklistDetailScreen(checklist: checklist)
        }
    }
}

struct ChecklistDetailScreen: View {
    let checklist: Checklist
    @State private var completed: Set<UUID> = []

    private var progress: Double {
        checklist.items.isEmpty ? 0 : Double(completed.count) / Double(checklist.items.count)
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .tint(checklist.isEmergency ? .red : .green)
                    Text("\(completed.count) of \(checklist.items.count) complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .hwGlassCard(cornerRadius: 16)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(checklist.items) { item in
                    Button {
                        toggle(item)
                    } label: {
                        HStack {
                            Image(systemName: completed.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(completed.contains(item.id) ? .green : .secondary)
                                .font(.title3)
                            Text(item.challenge)
                                .strikethrough(completed.contains(item.id), color: .secondary)
                            Spacer()
                            Text(item.response)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(completed.contains(item.id) ? .secondary : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(checklist.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    withAnimation { completed.removeAll() }
                }
                .disabled(completed.isEmpty)
            }
        }
    }

    private func toggle(_ item: ChecklistItem) {
        withAnimation(.snappy) {
            if completed.contains(item.id) {
                completed.remove(item.id)
            } else {
                completed.insert(item.id)
            }
        }
    }
}
