import SwiftUI
import SwiftData

struct LogbookScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LogEntry.date, order: .reverse) private var entries: [LogEntry]

    @State private var showingEditor = false

    private var totalHours: Double { entries.reduce(0) { $0 + $1.totalHours } }
    private var totalLandings: Int { entries.reduce(0) { $0 + $1.dayLandings + $1.nightLandings } }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Flights Logged",
                        systemImage: "book.closed",
                        description: Text("Tap + to log your first flight.")
                    )
                } else {
                    List {
                        Section {
                            totalsCard
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                        Section("Flights") {
                            ForEach(entries) { entry in
                                LogEntryRow(entry: entry)
                            }
                            .onDelete(perform: delete)
                        }
                    }
                }
            }
            .navigationTitle("Logbook")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                LogEntryEditor()
            }
        }
    }

    private var totalsCard: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("Total Time")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f h", totalHours))
                    .font(.headline)
                    .monospacedDigit()
            }
            VStack(spacing: 4) {
                Text("Flights")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(entries.count)")
                    .font(.headline)
                    .monospacedDigit()
            }
            VStack(spacing: 4) {
                Text("Landings")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(totalLandings)")
                    .font(.headline)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .hwGlassCard()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(entries[index])
        }
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(entry.fromIdent) → \(entry.toIdent)")
                    .font(.subheadline.weight(.semibold))
                    .monospaced()
                Spacer()
                Text(String(format: "%.1f h", entry.totalHours))
                    .font(.subheadline)
                    .monospacedDigit()
            }
            HStack {
                Text(entry.date, style: .date)
                if !entry.tailNumber.isEmpty {
                    Text("·")
                    Text(entry.tailNumber)
                }
                if !entry.aircraftType.isEmpty {
                    Text("·")
                    Text(entry.aircraftType)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !entry.remarks.isEmpty {
                Text(entry.remarks)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

struct LogEntryEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var entry = LogEntry()

    var body: some View {
        NavigationStack {
            Form {
                Section("Flight") {
                    DatePicker("Date", selection: $entry.date, displayedComponents: .date)
                    TextField("Aircraft type (e.g. C172)", text: $entry.aircraftType)
                        .textInputAutocapitalization(.characters)
                    TextField("Tail number", text: $entry.tailNumber)
                        .textInputAutocapitalization(.characters)
                    TextField("From (e.g. KPAO)", text: $entry.fromIdent)
                        .textInputAutocapitalization(.characters)
                    TextField("To", text: $entry.toIdent)
                        .textInputAutocapitalization(.characters)
                }
                Section("Time") {
                    hoursField("Total", $entry.totalHours)
                    hoursField("PIC", $entry.picHours)
                    hoursField("Night", $entry.nightHours)
                    hoursField("Instrument", $entry.instrumentHours)
                }
                Section("Landings") {
                    Stepper("Day: \(entry.dayLandings)", value: $entry.dayLandings, in: 0...99)
                    Stepper("Night: \(entry.nightLandings)", value: $entry.nightLandings, in: 0...99)
                }
                Section("Remarks") {
                    TextField("Remarks", text: $entry.remarks, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(entry)
                        dismiss()
                    }
                    .disabled(entry.totalHours <= 0)
                }
            }
        }
    }

    private func hoursField(_ label: String, _ value: Binding<Double>) -> some View {
        LabeledContent(label) {
            TextField("0.0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }
}
