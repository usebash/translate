import SwiftUI

struct DiagnosticsSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if !appState.logLines.isEmpty {
            Section {
                ForEach(appState.logLines, id: \.self) { line in
                    Text(line)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Button("Clear Log", role: .destructive) {
                    appState.clearLog()
                }
            } header: {
                Text("Diagnostics")
            }
        }
    }
}
