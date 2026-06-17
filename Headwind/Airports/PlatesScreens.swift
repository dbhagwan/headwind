import SwiftUI
import PDFKit
import HeadwindCore

/// Terminal procedures for one airport, grouped the way pilots expect.
struct PlatesListScreen: View {
    let airport: Airport

    @Environment(PlateStore.self) private var plates

    var body: some View {
        List {
            if let status = plates.currencyStatus(), !isCurrent(status) {
                Section {
                    StaleDataBanner(
                        status: status,
                        onUpdate: { Task { await plates.refreshFromRemote() } },
                        isUpdating: plates.isCheckingForUpdate
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            ForEach(plates.index.groupedPlates(for: airport.ident), id: \.category) { group in
                Section(group.category) {
                    ForEach(group.plates) { plate in
                        NavigationLink(value: plate) {
                            Text(plate.name)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle("\(airport.ident) Procedures")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ApproachPlate.self) { plate in
            PlateViewerScreen(plate: plate)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("Cycle \(plates.cycle)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func isCurrent(_ status: DataCurrency.Status) -> Bool {
        if case .current = status { return true }
        return false
    }
}

/// Renders one plate PDF, served through the offline cache.
struct PlateViewerScreen: View {
    let plate: ApproachPlate

    @Environment(PlateStore.self) private var plates
    @State private var document: PDFDocument?
    @State private var errorText: String?

    var body: some View {
        Group {
            if let document {
                PlatePDFView(document: document)
                    .ignoresSafeArea(edges: .bottom)
            } else if let errorText {
                ContentUnavailableView(
                    "Couldn't Load Plate",
                    systemImage: "doc.questionmark",
                    description: Text(errorText)
                )
            } else {
                ProgressView("Loading plate…")
            }
        }
        .navigationTitle(plate.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                let data = try await PlateCache.shared.pdf(cycle: plates.cycle, pdfName: plate.pdfName)
                guard let pdf = PDFDocument(data: data) else {
                    errorText = "The downloaded file isn't a readable PDF."
                    return
                }
                document = pdf
            } catch {
                errorText = "Check your connection and try again. (\(error.localizedDescription))"
            }
        }
    }
}

private struct PlatePDFView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
        }
    }
}
