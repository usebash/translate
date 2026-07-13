import Foundation
import FoundationModels
import Observation

// MARK: - Structured output the model is constrained to produce

@available(iOS 26.0, *)
@Generable
struct WordExample: Codable, Equatable {
    @Guide(description: "A short, natural example sentence in the word's own language")
    var original: String

    @Guide(description: "Faithful translation of that example sentence into the explanation language")
    var translation: String
}

@available(iOS 26.0, *)
@Generable
struct WordSense: Codable, Equatable {
    @Guide(description: "Short label for this specific meaning, phrased in the explanation language, e.g. 'to continue (doing something)'")
    var meaning: String

    @Guide(description: "How this sense is actually used: required prepositions/case, separable prefixes, register, or context. Written in the explanation language.")
    var usageNotes: String

    @Guide(description: "Example sentences that demonstrate this specific sense", .minimumCount(1), .maximumCount(2))
    var examples: [WordExample]
}

@available(iOS 26.0, *)
@Generable
struct WordExplanation: Codable, Equatable {
    @Guide(description: "The headword in its base/dictionary form")
    var headword: String

    @Guide(description: "Every distinct sense the headword genuinely has, most common first. Exactly one entry if it only has one meaning.", .minimumCount(1), .maximumCount(4))
    var senses: [WordSense]
}

// MARK: - Service

@available(iOS 26.0, *)
@MainActor
@Observable
final class WordExplainer {
    enum State: Equatable {
        case idle
        case loading
        case unavailable(String)
        case loaded(WordExplanation)
        case failed(String)
    }

    private(set) var state: State = .idle

    private var currentTask: Task<Void, Never>?

    func explain(word: String, sourceLanguage: AppLanguage, targetLanguage: AppLanguage) {
        currentTask?.cancel()

        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            state = .unavailable(Self.describe(availability))
            return
        }

        state = .loading

        currentTask = Task {
            let instructions = Instructions {
                """
                You are a precise, conservative bilingual dictionary for \(sourceLanguage.displayName) \
                learners whose explanation language is \(targetLanguage.displayName).
                Given a single word or short fixed phrase, list every distinct sense it genuinely has.
                For each sense give a short meaning label, a usage explanation (grammar, prepositions, \
                case, separable prefixes, register), and one or two natural example sentences with \
                translations. Never invent meanings the word doesn't have. If it only has one meaning, \
                return exactly one sense. Be concise, like a language teacher's notes, not an essay.
                """
            }

            let session = LanguageModelSession(instructions: instructions)

            do {
                let response = try await session.respond(
                    to: "Explain the \(sourceLanguage.displayName) word or phrase: \(word)",
                    generating: WordExplanation.self
                )
                guard !Task.isCancelled else { return }
                state = .loaded(response.content)
            } catch is CancellationError {
                // Superseded by a newer lookup; ignore.
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
    }

    private static func describe(_ availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available:
            return ""
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support on-device Apple Intelligence, so word explanations aren't available."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings > Apple Intelligence & Siri to get word explanations."
        case .unavailable(.modelNotReady):
            return "The on-device language model is still downloading. Try again in a bit."
        case .unavailable:
            return "Word explanations aren't available on this device right now."
        }
    }
}
