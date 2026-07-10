import SwiftUI
import SwiftData
import VisionKit
import PhotosUI
import HeadwindCore

/// Scan paper logbook pages and import the recognized entries.
///
/// Camera (document scanner) or photo-library import → on-device OCR →
/// on-device structuring → pilot reviews and edits every entry before
/// anything is written to the logbook.
struct LogbookScanScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var scanner = LogbookScanService()
    @State private var showingCamera = false
    @State private var photoSelection: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            Group {
                switch scanner.phase {
                case .idle:
                    sourcePicker
                case .recognizing(let page, let total):
                    progress("Reading page \(page) of \(total)…")
                case .structuring:
                    progress("Structuring entries…")
                case .done:
                    reviewList
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Scan Failed", systemImage: "doc.viewfinder")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { scanner.reset() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Scan Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if case .done = scanner.phase {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import \(includedCount)") { importEntries() }
                            .disabled(includedCount == 0)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                DocumentCameraView { images in
                    showingCamera = false
                    guard !images.isEmpty else { return }
                    Task { await scanner.process(images: images) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoSelection) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    var images: [UIImage] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    photoSelection = []
                    if !images.isEmpty {
                        await scanner.process(images: images)
                    }
                }
            }
            .task {
                if ProcessInfo.processInfo.arguments.contains("-screenshotScanReview") {
                    scanner.seedDemoEntries()
                }
            }
        }
    }

    private var includedCount: Int {
        scanner.entries.filter(\.include).count
    }

    // MARK: Source picker

    private var sourcePicker: some View {
        VStack(spacing: 20) {
            IconBadge(systemName: "doc.viewfinder", tint: .indigo)
                .scaleEffect(1.6)
                .padding(.bottom, 8)
            Text("Import Your Paper Logbook")
                .font(.title3.weight(.semibold))
            Text("Photograph logbook pages and Headwind reads the rows into digital entries. Everything runs on this device — your logbook never leaves it. You review every entry before it's saved.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                if VNDocumentCameraViewController.isSupported {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Scan with Camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                PhotosPicker(selection: $photoSelection, maxSelectionCount: 10, matching: .images) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: 480)
    }

    private func progress(_ label: String) -> some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Review

    private var reviewList: some View {
        List {
            Section {
                Label(scanner.engineDescription, systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            Section("Review Before Import") {
                ForEach($scanner.entries) { $entry in
                    ScannedEntryRow(entry: $entry)
                }
            }
            Section {
                Text("Check every entry against the page — OCR makes mistakes and your logbook is a legal record. Total time is copied to PIC; adjust after import if you log differently.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func importEntries() {
        for entry in scanner.entries where entry.include {
            context.insert(entry.toLogEntry())
        }
        dismiss()
    }
}

/// One scanned row: toggle, headline summary, and inline editing.
private struct ScannedEntryRow: View {
    @Binding var entry: ScannedLogEntry
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Toggle("Include entry", isOn: $entry.include)
                    .labelsHidden()
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(entry.date, format: .dateTime.year().month().day())
                            .font(.subheadline.weight(.semibold))
                        if !entry.fromIdent.isEmpty {
                            Text("\(entry.fromIdent) → \(entry.toIdent.isEmpty ? entry.fromIdent : entry.toIdent)")
                                .font(.subheadline)
                                .monospaced()
                        }
                    }
                    Text("\(entry.aircraftType) \(entry.tailNumber) · \(entry.totalHours, format: .number.precision(.fractionLength(1))) h · \(entry.landings) ldg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.snappy) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "pencil")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if expanded {
                VStack(spacing: 8) {
                    DatePicker("Date", selection: $entry.date, displayedComponents: .date)
                    HStack {
                        TextField("Type", text: $entry.aircraftType)
                        TextField("Tail", text: $entry.tailNumber)
                    }
                    HStack {
                        TextField("From", text: $entry.fromIdent)
                        TextField("To", text: $entry.toIdent)
                    }
                    HStack {
                        LabeledContent("Hours") {
                            TextField("0.0", value: $entry.totalHours, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                        }
                        LabeledContent("Landings") {
                            TextField("0", value: $entry.landings, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                        }
                    }
                    TextField("Remarks", text: $entry.remarks, axis: .vertical)
                    if !entry.sourceText.isEmpty {
                        Text(entry.sourceText)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .font(.subheadline)
            }
        }
        .opacity(entry.include ? 1 : 0.45)
    }
}

/// VNDocumentCameraViewController wrapper: multi-page paper scanning
/// with perspective correction, exactly what logbook pages need.
private struct DocumentCameraView: UIViewControllerRepresentable {
    let onFinish: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: VNDocumentCameraViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void
        init(onFinish: @escaping ([UIImage]) -> Void) { self.onFinish = onFinish }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            onFinish((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish([])
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onFinish([])
        }
    }
}
