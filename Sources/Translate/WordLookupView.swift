import SwiftUI
import Translation

struct WordLookupView: View {
    let term: String

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var entry: DictionaryEntry?
    @State private var lookedUp = false

    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var pendingExplanationText = ""
    @State private var explanationTranslation = ""
    @State private var isTranslatingExplanation = false

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
            guard !pendingExplanationText.isEmpty else { return }
            isTranslatingExplanation = true
            defer { isTranslatingExplanation = false }
            do {
                let response = try await session.translate(pendingExplanationText)
                explanationTranslation = response.targetText
            } catch {
                explanationTranslation = ""
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let entry {
            ForEach(Array(entry.senses.enumerated()), id: \.offset) { index, sense in
                senseCard(index: index + 1, sense: sense)
            }

            translateButton(for: entry)

            if !explanationTranslation.isEmpty {
                glassCard {
                    Text("Перевод")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.gray)
                    Text(explanationTranslation)
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(sense.gloss)
                        .foregroundStyle(.white)
                        .font(.headline)
                    if !sense.pos.isEmpty {
                        Text(sense.pos)
                            .foregroundStyle(.gray)
                            .font(.caption)
                    }
                }
            }

            ForEach(sense.examples, id: \.self) { example in
                Text(example)
                    .foregroundStyle(.white.opacity(0.85))
                    .italic()
                    .font(.footnote)
                    .padding(.leading, 4)
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

    private func translateButton(for entry: DictionaryEntry) -> some View {
        Button {
            translateExplanation(for: entry)
        } label: {
            HStack {
                if isTranslatingExplanation {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "arrow.left.arrow.right")
                }
                Text("Перевести объяснение")
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isTranslatingExplanation)
    }

    private func translateExplanation(for entry: DictionaryEntry) {
        let text = entry.senses
            .map { ([$0.gloss] + $0.examples).joined(separator: ". ") }
            .joined(separator: "\n")
        pendingExplanationText = text

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