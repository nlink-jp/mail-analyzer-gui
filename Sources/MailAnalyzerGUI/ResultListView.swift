import SwiftUI

// Fixed status palette from the legacy CSS: error/suspicious #e74c3c,
// analyzing #3498db, safe #27ae60 (#2ecc71 in dark mode).
enum StatusPalette {
    static let alert = Color(red: 0xE7 / 255, green: 0x4C / 255, blue: 0x3C / 255)
    static let analyzing = Color(red: 0x34 / 255, green: 0x98 / 255, blue: 0xDB / 255)

    static func safe(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0x2E / 255, green: 0xCC / 255, blue: 0x71 / 255)
            : Color(red: 0x27 / 255, green: 0xAE / 255, blue: 0x60 / 255)
    }
}

struct ResultListView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.entries.isEmpty {
            Text(L("No results yet"))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(24)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 2) {
                ForEach(model.entries) { entry in
                    ResultRow(
                        entry: entry,
                        isExpanded: model.expanded.contains(entry.id),
                        toggle: { model.toggleExpanded(entry.id) })
                }
            }
        }
    }
}

struct ResultRow: View {
    let entry: AppModel.MailEntry
    let isExpanded: Bool
    let toggle: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 8) {
                    Text(statusIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(statusColor)
                        .frame(minWidth: 24)
                    Text(entry.fileName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    trailingLabel
                    Text(isExpanded ? "v" : ">")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 16)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                expandedBody
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.3))
        )
    }

    // Legacy statusIcon(): analyzing "...", error "!!", suspicious "!!",
    // result "OK", otherwise blank (pending).
    private var statusIcon: String {
        switch entry.state {
        case .analyzing: return "..."
        case .error: return "!!"
        case .done(let result): return result.judgment.isSuspicious ? "!!" : "OK"
        case .pending: return ""
        }
    }

    // Legacy statusClass(): error/analyzing take precedence, then
    // suspicious, then safe.
    private var statusColor: Color {
        switch entry.state {
        case .error: return StatusPalette.alert
        case .analyzing: return StatusPalette.analyzing
        case .done(let result):
            return result.judgment.isSuspicious ? StatusPalette.alert : StatusPalette.safe(colorScheme)
        case .pending: return StatusPalette.safe(colorScheme)
        }
    }

    @ViewBuilder
    private var trailingLabel: some View {
        switch entry.state {
        case .analyzing:
            ProgressView()
                .controlSize(.small)
        case .done(let result):
            Text("\(result.judgment.category) \(Int((result.judgment.confidence * 100).rounded()))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(statusColor)
        case .error:
            Text(L("Error"))
                .font(.system(size: 12))
                .foregroundStyle(StatusPalette.alert)
        case .pending:
            EmptyView()
        }
    }

    @ViewBuilder
    private var expandedBody: some View {
        switch entry.state {
        case .done(let result):
            ResultDetailView(result: result)
        case .error(let message):
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(StatusPalette.alert)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .analyzing:
            Text(L("Analyzing..."))
                .font(.system(size: 13))
                .foregroundStyle(StatusPalette.analyzing)
        case .pending:
            EmptyView()
        }
    }
}
