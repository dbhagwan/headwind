import SwiftUI
import HeadwindCore

extension DataCurrency.Status {
    var tint: Color {
        switch self {
        case .current: .green
        case .expiringSoon: .orange
        case .expired: .red
        }
    }

    var systemImage: String {
        switch self {
        case .current: "checkmark.seal.fill"
        case .expiringSoon: "clock.badge.exclamationmark.fill"
        case .expired: "exclamationmark.triangle.fill"
        }
    }

    var label: String {
        switch self {
        case .current(let days): "Current · \(days) days left"
        case .expiringSoon(let days): days == 1 ? "Expires tomorrow" : "Expires in \(days) days"
        case .expired(let days): days == 0 ? "Expired today" : "Expired \(days) days ago"
        }
    }
}

/// Compact pill showing a dataset's currency status.
struct DataCurrencyBadge: View {
    let status: DataCurrency.Status

    var body: some View {
        Label(status.label, systemImage: status.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tint)
    }
}

/// Full-width warning shown above out-of-date charts/plates.
struct StaleDataBanner: View {
    let status: DataCurrency.Status
    var onUpdate: (() -> Void)?
    var isUpdating: Bool = false

    var body: some View {
        if case .current = status {
            EmptyView()
        } else {
            HStack(spacing: 10) {
                Image(systemName: status.systemImage)
                    .foregroundStyle(status.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.label)
                        .font(.subheadline.weight(.semibold))
                    if case .expired = status {
                        Text("Not for navigation until updated.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let onUpdate {
                    if isUpdating {
                        ProgressView()
                    } else {
                        Button("Update", action: onUpdate)
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(12)
            .background(status.tint.opacity(0.12), in: .rect(cornerRadius: 14))
        }
    }
}
