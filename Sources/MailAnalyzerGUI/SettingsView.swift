import SwiftUI

// Stub — the real settings editor lands with the settings-sheet commit.
struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack {
            Text(L("Settings"))
            Button(L("Cancel")) { model.showSettings = false }
        }
        .padding(24)
        .frame(width: 540)
    }
}
