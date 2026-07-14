import SwiftUI
import Translation

struct WordLookupView: View {
    let term: String

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var entry: DictionaryEntry?
    @State private var lookedUp = false

    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var pendingTranslationText = ""
    @State private var translationResults: [String: String] = [:]
    @State private var translatingKey: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        content
                    }
                    .padding(16)
                }
            }
            .navigationTitle(term)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .tint(.white)
        .onAppear {
            entry = GermanDictionary.shared.lookup(term)
            lookedUp = true
        }
        .translationTask(translationConfiguration) { session in
            guard !pendingTranslationText.isEmpty else { return }
            defer { translatingKey = nil }
            do {
                let response = try await session.translate(pendingTranslationText)
                translationResults[pendingTranslationText] = response.targetText
            } catch {
                translationResults[pendingTranslationText] = nil
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let entry {
            ForEach(Array(entry.senses.enumerated()), id: \.offset) { index, sense in
                senseCard(index: index + 1, sense: sense)
            }
        } else if lookedUp {
            Text("В офлайн-словаре нет статьи для «\(term)».")
                .foregroundStyle(.gray)
                .padding(.top, 24)
        } else {
            ProgressView().tint(.white).padding(.top, 24)
        }
    }

    private func senseCard(index: Int, sense: DictionarySense) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(index).")
                    .foregroundStyle(.gray)
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Text(sense.displayGloss)
                        .foregroundStyle(.white)
                        .font(.headline)

                    if !sense.hasCuratedTranslation {
                        HStack(spacing: 8) {
                            Text("нет перевода в словаре")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            translateChip(for: sense.glossDe)
                        }
                        if let translated = translationResults[sense.glossDe] {
                            Text(translated)
                                .foregroundStyle(.gray)
                                .font(.footnote)
                        }
                    }

                    if !sense.pos.isEmpty {
                        Text(sense.pos)
                            .foregroundStyle(.gray)
                            .font(.caption)
                    }
                }
            }

            ForEach(sense.examples, id: \.self) { example in
                exampleRow(example)
            }

            if !sense.synonyms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Похожие слова")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.gray)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sense.synonyms, id: \.self) { synonym in
                                Text(synonym)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.08), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func exampleRow(_ example: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(example)
                    .foregroundStyle(.white.opacity(0.85))
                    .italic()
                    .font(.footnote)
                Spacer()
                translateChip(for: example)
            }
            if let translated = translationResults[example] {
                Text(translated)
                    .foregroundStyle(.gray)
                    .font(.footnote)
            }
        }
        .padding(.leading, 4)
    }

    private func translateChip(for text: String) -> some View {
        Button {
            requestTranslation(of: text)
        } label: {
            if translatingKey == text {
                ProgressView().tint(.white)
            } else {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
    }

    private func requestTranslation(of text: String) {
        guard !text.isEmpty else { return }
        pendingTranslationText = text
        translatingKey = text

        let targetLanguage = appState.sourceLanguage == .german ? appState.targetLanguage : appState.sourceLanguage
        if translationConfiguration == nil {
            translationConfiguration = TranslationSession.Configuration(
                source: AppLanguage.german.locale,
                target: targetLanguage.locale
            )
        } else {
            translationConfiguration?.invalidate()
        }
    }
}