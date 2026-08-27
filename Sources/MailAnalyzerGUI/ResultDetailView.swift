import SwiftUI
import MailAnalyzerGUICore

// Port of legacy ResultDetail.svelte. Category badge colors are fixed
// across light/dark (legacy CSS hard-coded them).
struct ResultDetailView: View {
    let result: AnalysisResult

    /// Per-row toggle, default collapsed — view identity (the entry id)
    /// keeps it independent per result, legacy behavior.
    @State private var showIndicators = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if !result.judgment.summary.isEmpty {
                Text(result.judgment.summary)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
            }
            if !result.judgment.reasons.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(result.judgment.reasons.enumerated()), id: \.offset) { _, reason in
                        Text("- \(reason)")
                            .font(.system(size: 12.5))
                            .textSelection(.enabled)
                    }
                }
            }
            if !result.judgment.tags.isEmpty {
                FlowTags(tags: result.judgment.tags)
            }
            Button(showIndicators ? L("Hide Indicators") : L("Show Indicators")) {
                showIndicators.toggle()
            }
            .buttonStyle(.link)
            .font(.system(size: 12))
            if showIndicators {
                indicators
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(result.judgment.category.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(categoryColor(result.judgment.category), in: RoundedRectangle(cornerRadius: 4))
                Text("\(Int((result.judgment.confidence * 100).rounded()))%")
                    .font(.system(size: 12, weight: .medium))
                if result.judgment.isSuspicious {
                    Text(L("SUSPICIOUS"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(StatusPalette.alert)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(StatusPalette.alert))
                }
            }
            Text(result.subject.isEmpty ? L("(no subject)") : result.subject)
                .font(.system(size: 14, weight: .semibold))
                .textSelection(.enabled)
            HStack(spacing: 12) {
                if !result.from.isEmpty {
                    Text(result.from)
                }
                if !result.date.isEmpty {
                    Text(result.date)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
    }

    // Legacy categoryColor() hex map, verbatim.
    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "phishing": return Color(red: 0xE7 / 255, green: 0x4C / 255, blue: 0x3C / 255)
        case "spam": return Color(red: 0xE6 / 255, green: 0x7E / 255, blue: 0x22 / 255)
        case "malware-delivery": return Color(red: 0xC0 / 255, green: 0x39 / 255, blue: 0x2B / 255)
        case "bec": return Color(red: 0xE7 / 255, green: 0x4C / 255, blue: 0x3C / 255)
        case "scam": return Color(red: 0xD3 / 255, green: 0x54 / 255, blue: 0x00 / 255)
        case "safe": return Color(red: 0x27 / 255, green: 0xAE / 255, blue: 0x60 / 255)
        default: return Color(red: 0x88 / 255, green: 0x88 / 255, blue: 0x88 / 255)
        }
    }

    // MARK: - Indicators

    private var indicators: some View {
        VStack(alignment: .leading, spacing: 12) {
            indicatorSection(L("Authentication")) {
                HStack(spacing: 6) {
                    authBadge("SPF", result.indicators.authentication.spf)
                    authBadge("DKIM", result.indicators.authentication.dkim)
                    authBadge("DMARC", result.indicators.authentication.dmarc)
                }
            }

            indicatorSection(L("Sender")) {
                let sender = result.indicators.sender
                VStack(alignment: .leading, spacing: 3) {
                    if sender.fromReturnPathMismatch { warnText(L("From/Return-Path mismatch")) }
                    if sender.displayNameSpoofing { warnText(L("Display name spoofing")) }
                    if sender.replyToDivergence { warnText(L("Reply-To divergence")) }
                    if !sender.details.isEmpty {
                        Text(sender.details)
                            .font(.system(size: 12))
                            .textSelection(.enabled)
                    }
                    if !sender.fromReturnPathMismatch && !sender.displayNameSpoofing && !sender.replyToDivergence {
                        Text(L("No issues detected"))
                            .font(.system(size: 12))
                            .foregroundStyle(StatusPalette.safe(colorScheme))
                    }
                }
            }

            if !result.indicators.urls.isEmpty {
                indicatorSection(L("URLs (%d)", result.indicators.urls.count)) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(result.indicators.urls.enumerated()), id: \.offset) { _, url in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(url.url)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(url.suspicious ? StatusPalette.alert : Color.primary)
                                    .textSelection(.enabled)
                                if url.suspicious && !url.reason.isEmpty {
                                    warnText(url.reason)
                                }
                            }
                        }
                    }
                }
            }

            if !result.indicators.attachments.isEmpty {
                indicatorSection(L("Attachments (%d)", result.indicators.attachments.count)) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(result.indicators.attachments.enumerated()), id: \.offset) { _, att in
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Text(att.filename)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(att.suspicious ? StatusPalette.alert : Color.primary)
                                    Text("\(att.mimeType) (\(L("%llu bytes", att.size)))")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .textSelection(.enabled)
                                if att.suspicious && !att.reason.isEmpty {
                                    warnText(att.reason)
                                }
                            }
                        }
                    }
                }
            }

            indicatorSection(L("Routing")) {
                let routing = result.indicators.routing
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Hops: %d", Int(routing.hopCount)))
                        .font(.system(size: 12))
                    if !routing.xMailer.isEmpty {
                        Text(L("X-Mailer: %@", routing.xMailer))
                            .font(.system(size: 12))
                            .foregroundStyle(routing.xMailerSuspicious ? StatusPalette.alert : Color.primary)
                            .textSelection(.enabled)
                    }
                    ForEach(Array(routing.suspiciousHops.enumerated()), id: \.offset) { _, hop in
                        warnText(hop)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func indicatorSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func warnText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(StatusPalette.alert)
            .textSelection(.enabled)
    }

    // Legacy authBadge(): pass → green, fail/softfail/permerror → red,
    // anything else neutral; empty value renders as "none".
    private func authBadge(_ label: String, _ value: String) -> some View {
        let display = value.isEmpty ? L("none") : value
        let color: Color
        switch value {
        case "pass":
            color = StatusPalette.safe(colorScheme)
        case "fail", "softfail", "permerror":
            color = StatusPalette.alert
        default:
            color = .secondary
        }
        return Text("\(label): \(display)")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(color.opacity(0.6)))
    }
}

/// Rounded tag pills, wrapping across lines (legacy flex-wrap parity).
struct FlowTags: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                Text(tag)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
