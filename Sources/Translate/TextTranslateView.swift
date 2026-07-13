import SwiftUI

struct TextTranslateView: View {
    @Environment(AppState.self) private var appState
    @State private var sourceText: String = ""
    @State private var lookupRequest: WordLookupRequest?
    @State private var dictation = SpeechDictation()

    var body: some View {
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

                            if let errorMessage = dictation.errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }

                            HStack(spacing: 16) {
                                Spacer()

                                Button {
                                    toggleDictation()
                                } label: {
                                    Image(systemName: dictation.isListening ? "mic.fill" : "mic")
                                        .foregroundStyle(dictation.isListening ? .red : .white)
                                }

                                Button {
                                    appState.speak(sourceText, language: appState.sourceLanguage)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundStyle(.white)
                                }
                                .disabled(sourceText.isEmpty)
                            }
                        }

                        if let word = singleWord(in: sourceText) {
                            meaningsButton(word, language: appState.sourceLanguage)
                        } else {
                            wordChips(for: sourceText, language: appState.sourceLanguage)
                        }

                        if appState.isTranslating {
                            ProgressView()
                                .tint(.white)
                        }

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

                            if let word = singleWord(in: appState.translatedText) {
                                meaningsButton(word, language: appState.targetLanguage)
                            } else {
                                wordChips(for: appState.translatedText, language: appState.targetLanguage)
                            }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $lookupRequest) { request in
                WordLookupView(
                    term: request.term,
                    wordLanguage: request.language,
                    explanationLanguage: request.language == appState.sourceLanguage
                        ? appState.targetLanguage
                        : appState.sourceLanguage
                )
            }
        }
        .tint(.white)
    }

    private func toggleDictation() {
        if dictation.isListening {
            dictation.stop()
        } else {
            dictation.start(locale: appState.sourceLanguage.speechRecognitionLocale) { text, _ in
                sourceText = text
                appState.scheduleLiveTranslation(text: text)
            }
        }
    }

    private func singleWord(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }) else { return nil }
        let cleaned = trimmed.trimmingCharacters(in: .punctuationCharacters)
        guard isLookupCandidate(cleaned) else { return nil }
        return cleaned
    }

    private func meaningsButton(_ word: String, language: AppLanguage) -> some View {
        Button {
            lookupRequest = WordLookupRequest(term: word, language: language)
        } label: {
            HStack {
                Image(systemName: "character.book.closed.fill")
                Text("Show all meanings")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func wordChips(for text: String, language: AppLanguage) -> some View {
        let words = text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
            .filter { !$0.isEmpty }

        return Group {
            if !words.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(words, id: \.self) { word in
                            Button {
                                let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
                                if isLookupCandidate(cleaned) {
                                    lookupRequest = WordLookupRequest(term: cleaned, language: language)
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

private struct WordLookupRequest: Identifiable {
    let term: String
    let language: AppLanguage
    var id: String { term + "-" + language.rawValue }
}
