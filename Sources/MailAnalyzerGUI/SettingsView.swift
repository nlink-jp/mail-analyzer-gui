import SwiftUI
import MailAnalyzerGUICore

// Port of the legacy settings modal. Settings are reloaded every time the
// sheet opens; Cancel discards edits; Save persists and auto-closes after
// ~600 ms (legacy timing). No PATH auto-detection and no file browser for
// the binary path — deliberate anti-binary-injection design.
struct SettingsView: View {
    @ObservedObject var model: AppModel

    @State private var binaryPath = ""
    @State private var envRows: [EnvRow] = []
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Settings"))
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text(L("Analyzer binary path"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("/usr/local/bin/mail-analyzer", text: $binaryPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }

            Text(L("Environment Variables"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(EnvTemplate.all, id: \.name) { template in
                    Button(template.name) {
                        envRows = template.apply(to: envRows)
                    }
                    .font(.system(size: 12))
                }
            }

            ScrollView {
                VStack(spacing: 6) {
                    ForEach($envRows) { $row in
                        HStack(spacing: 6) {
                            TextField(L("KEY"), text: $row.key)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 210)
                            TextField(EnvTemplate.placeholder(for: row.key), text: $row.value)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                            Button {
                                envRows.removeAll { $0.id == row.id }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    Button(L("+ Add variable")) {
                        envRows.append(EnvRow(key: "", value: ""))
                    }
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: 260)

            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button(L("Cancel")) {
                    model.showSettings = false
                }
                .keyboardShortcut(.cancelAction)
                Button(L("Save")) {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 540)
        .onAppear(perform: load)
    }

    private func load() {
        let settings = AnalyzerSettings.load(from: model.defaults)
        binaryPath = settings.binaryPath
        envRows = EnvRows.fromSettings(settings.envVars)
        message = ""
    }

    private func save() {
        let settings = AnalyzerSettings(
            binaryPath: binaryPath,
            envVars: EnvRows.sanitizeForSave(envRows))
        settings.save(to: model.defaults)
        message = L("Settings saved.")
        model.closeSettingsAfterSave()
    }
}
