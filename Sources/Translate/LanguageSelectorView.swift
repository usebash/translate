import SwiftUI

struct LanguageSelectorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        HStack {
            Picker("Source", selection: $appState.sourceLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text("\(language.flag) \(language.displayName)").tag(language)
                }
            }
            .pickerStyle(.menu)

            Button {
                appState.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.borderless)

            Picker("Target", selection: $appState.targetLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text("\(language.flag) \(language.displayName)").tag(language)
                }
            }
            .pickerStyle(.menu)
        }
    }
}
