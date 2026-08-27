import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            DropZoneVisual(highlighted: model.isDropTargeted)
            ScrollView {
                ResultListView(model: model)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(16)
        .frame(minWidth: 480, minHeight: 360)
        .background(DropHostView(model: model))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !model.entries.isEmpty {
                    Button(L("Clear")) { model.clear() }
                }
                if model.hasResults {
                    Button(L("Export JSON")) { model.exportJSON() }
                }
                Button(L("Settings")) { model.showSettings = true }
            }
        }
        .overlay(alignment: .bottom) {
            if let notice = model.notice {
                NoticeBanner(text: notice)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.notice)
        .alert(
            model.exportMessage ?? "",
            isPresented: Binding(
                get: { model.exportMessage != nil },
                set: { if !$0 { model.exportMessage = nil } })
        ) {
            Button(L("OK"), role: .cancel) {}
        }
        .sheet(isPresented: $model.showSettings) {
            SettingsView(model: model)
        }
    }
}

/// The visual drop hint. Purely decorative — the effective drop target is
/// the whole window (legacy behavior, kept deliberately).
struct DropZoneVisual: View {
    var highlighted: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.up.doc")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(highlighted ? Color.accentColor : Color.secondary)
            Text(L(".eml / .msg files here"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(highlighted ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    highlighted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
        )
    }
}

struct NoticeBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.3)))
    }
}
