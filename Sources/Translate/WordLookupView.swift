import SwiftUI

@available(iOS 26.0, *)
struct WordLookupView: View {
    let term: String
    let wordLanguage: AppLanguage
    let explanationLanguage: AppLanguage

    @Environment(\.dismiss) private var dismiss
    @State private var explainer = WordExplainer()

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
        .task {
            explainer.explain(word: term, sourceLanguage: wordLanguage, targetLanguage: explanationLanguage)
        }
        .onDisappear {
            explainer.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch explainer.state {
        case .idle, .loading:
            HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text("Looking up \u{201C}\(term)\u{201D}\u{2026}")
                    .foregroundStyle(.white)
            }
            .padding(.top, 24)

        case .unavailable(let message):
            Text(message)
                .foregroundStyle(.gray)
                .padding(.top, 24)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text("Couldn't explain this word")
                    .foregroundStyle(.white)
                    .font(.headline)
                Text(message)
                    .foregroundStyle(.red)
                    .font(.footnote)
                Button("Try again") {
                    explainer.explain(word: term, sourceLanguage: wordLanguage, targetLanguage: explanationLanguage)
                }
                .foregroundStyle(.white)
            }
            .padding(.top, 24)

        case .loaded(let explanation):
            ForEach(Array(explanation.senses.enumerated()), id: \.offset) { index, sense in
                senseCard(index: index + 1, sense: sense)
            }
        }
    }

    private func senseCard(index: Int, sense: WordSense) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(index).")
                    .foregroundStyle(.gray)
                    .font(.headline)
                Text(sense.meaning)
                    .foregroundStyle(.white)
                    .font(.headline)
            }

            Text(sense.usageNotes)
                .foregroundStyle(.gray)
                .font(.subheadline)

            ForEach(Array(sense.examples.enumerated()), id: \.offset) { _, example in
                VStack(alignment: .leading, spacing: 2) {
                    Text(example.original)
                        .foregroundStyle(.white)
                        .italic()
                    Text(example.translation)
                        .foregroundStyle(.gray)
                }
                .font(.footnote)
                .padding(.leading, 4)
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
}

/// Simple heuristic for whether a token is worth sending to the on-device model at all
/// (skips empty strings, bare punctuation, and pure numbers).
func isLookupCandidate(_ term: String) -> Bool {
    !term.isEmpty && term.contains(where: \.isLetter)
}
