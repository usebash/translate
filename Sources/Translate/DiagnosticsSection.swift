import SwiftUI

struct DiagnosticsSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if !appState.logLines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Diagnostics")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.gray)

                ForEach(appState.logLines, id: \.self) { line in
                    Text(line)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.gray)
                }

                Button("Clear Log", role: .destructive) {
                    appState.clearLog()
                }
                .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}
