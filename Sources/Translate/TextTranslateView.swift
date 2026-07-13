import SwiftUI

struct TextTranslateView: View {
    @Environment(AppState.self) private var appState
    @State private var sourceText: String = "Hello, how are you?"

    var body: some View {
        NavigationStack {
            Form {
                Section("Language") {
                    LanguageSelectorView()
                }

                Section("Source Text") {
                    TextEditor(text: $sourceText)
                        .frame(minHeight: 100)
                }

                Section {
                    Button {
                        appState.requestTranslation(text: sourceText)
                    } label: {
                        if appState.isTranslating {
                            ProgressView()
                        } else {
                            Label("Translate", systemImage: "arrow.left.arrow.right")
                        }
                    }
                    .disabled(sourceText.isEmpty || appState.isTranslating)
                }

                if !appState.translatedText.isEmpty {
                    Section("Result") {
                        Text(appState.translatedText)
                    }
                }

                DiagnosticsSection()
            }
            .navigationTitle("Translate")
        }
    }
}
