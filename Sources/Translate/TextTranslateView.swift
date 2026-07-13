import SwiftUI

struct TextTranslateView: View {
    @Environment(AppState.self) private var appState
    @State private var sourceText: String = ""
    @State private var lookupTerm: String?

    var body: some View {
        @Bindable var appState = appState
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        LanguageSelectorView()
                            .padding(.top, 8)

                        glassCard {
                            ZStack(alignment: .topLeading) {
                                if sourceText.isEmpty {
                                    Text("Enter text..")
                                        .foregroundStyle(.gray)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                }
                                TextEditor(text: $sourceText)
                                    .scrollContentBackground(.hidden)
                                    .foregroundStyle(.white)
                                    .frame(minHeight: 120)
                                    .onChange(of: sourceText) { _, newValue in
                                        appState.scheduleLiveTranslation(text: newValue)
                                    }
                            }

                            if let pronunciation = appState.pronunciation(for: sourceText, language: appState.sourceLanguage) {
                                Text(pronunciation)
                                    .font(.footnote)
                                    .foregroundStyle(.gray)
                            }

                            HStack {
                                Toggle("Live", isOn: $appState.liveTranslationEnabled)
                                    .toggleStyle(.switch)
                                    .tint(.white)
                                    .font(.footnote)

                                Spacer()

                                Button {
                                    appState.speak(sourceText, language: appState.sourceLanguage)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundStyle(.white)
                                }
                                .disabled(sourceText.isEmpty)

                                if !appState.liveTranslationEnabled {
                                    Button {
                                        appState.requestTranslation(text: sourceText)
                                    } label: {
                                        if appState.isTranslating {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "arrow.left.arrow.right")
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .disabled(sourceText.isEmpty || appState.isTranslating)
                                }
                            }
                        }

                        wordChips(for: sourceText)

                        if !appState.translatedText.isEmpty {
                            glassCard {
                                Text("Translation")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.gray)

                                Text(appState.translatedText)
                                    .foregroundStyle(.white)
                                    .textSelection(.enabled)

                                if let pronunciation = appState.pronunciation(for: appState.translatedText, language: appState.targetLanguage) {
                                    Text(pronunciation)
                                        .font(.footnote)
                                        .foregroundStyle(.gray)
                                }

                                Button {
                                    appState.speak(appState.translatedText, language: appState.targetLanguage)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundStyle(.white)
                                }
                            }

                            wordChips(for: appState.translatedText)
                        }

                        if let lastError = appState.lastError {
                            glassCard {
                                Text(lastError)
                                    .foregroundStyle(.red)
                                    .font(.footnote)
                            }
                        }

                        DiagnosticsSection()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Translate")
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: Binding(
                get: { lookupTerm.map { IdentifiableString(value: $0) } },
                set: { lookupTerm = $0?.value }
            )) { item in
                WordLookupView(term: item.value)
            }
        }
        .tint(.white)
    }

    private func wordChips(for text: String) -> some View {
        let words = text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
            .filter { !$0.isEmpty }

        return Group {
            if !words.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(words, id: \.self) { word in
                            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
                            Button {
                                if canLookUp(term: cleaned) {
                                    lookupTerm = cleaned
                                }
                            } label: {
                                Text(word)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.08), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(!canLookUp(term: cleaned))
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}
