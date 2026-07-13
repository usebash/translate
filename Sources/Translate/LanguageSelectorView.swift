import SwiftUI

struct LanguageSelectorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        HStack(spacing: 12) {
            Menu {
                Picker("Source", selection: $appState.sourceLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            } label: {
                languagePill(appState.sourceLanguage.displayName)
            }

            Button {
                withAnimation(.snappy) {
                    appState.swapLanguages()
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)

            Menu {
                Picker("Target", selection: $appState.targetLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            } label: {
                languagePill(appState.targetLanguage.displayName)
            }
        }
    }

    private func languagePill(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.1), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
    }
}
