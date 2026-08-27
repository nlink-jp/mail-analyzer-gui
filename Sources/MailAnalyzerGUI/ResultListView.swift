import SwiftUI

// Stub — the expandable rows land in the next commit.
struct ResultListView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.entries.isEmpty {
            Text(L("No results yet"))
                .foregroundStyle(.secondary)
                .padding(24)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 2) {
                ForEach(model.entries) { entry in
                    Text(entry.fileName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
