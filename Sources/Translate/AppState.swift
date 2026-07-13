import Foundation
import Translation
import Observation
import AVFoundation

@MainActor
@Observable
final class AppState {
    var sourceLanguage: AppLanguage = .english
    var targetLanguage: AppLanguage = .russian

    var configuration: TranslationSession.Configuration?
    var pendingText: String = ""
    var translatedText: String = ""
    var isTranslating = false
    var logLines: [String] = []
    var lastError: String?

    private var lastSource: AppLanguage?
    private var lastTarget: AppLanguage?
    private var debounceTask: Task<Void, Never>?
    private let speechSynthesizer = AVSpeechSynthesizer()

    func log(_ message: String) {
        let timestamp = DateFormatter.diagnosticsFormatter.string(from: Date())
        logLines.append("[\(timestamp)] \(message)")
    }

    func clearLog() {
        logLines.removeAll()
    }

    func swapLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
    }

    func scheduleLiveTranslation(text: String) {
        debounceTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            translatedText = ""
            return
        }
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            requestTranslation(text: text)
        }
    }

    func requestTranslation(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard sourceLanguage != targetLanguage else {
            log("Source and target languages must differ")
            return
        }

        pendingText = text
        lastError = nil

        if configuration != nil, lastSource == sourceLanguage, lastTarget == targetLanguage {
            configuration?.invalidate()
        } else {
            lastSource = sourceLanguage
            lastTarget = targetLanguage
            configuration = TranslationSession.Configuration(
                source: sourceLanguage.locale,
                target: targetLanguage.locale
            )
        }
    }

    func handle(session: TranslationSession) async {
        guard !pendingText.isEmpty else { return }
        isTranslating = true
        defer { isTranslating = false }
        do {
            let response = try await session.translate(pendingText)
            translatedText = response.targetText
            log("OK, length=\(response.targetText.count)")
        } catch {
            translatedText = ""
            let nsError = error as NSError
            lastError = friendlyErrorMessage(for: nsError)
            log("ERROR domain=\(nsError.domain) code=\(nsError.code)")
        }
    }

    private func friendlyErrorMessage(for error: NSError) -> String {
        if error.domain == "Translation.TranslationError" {
            return "Translation failed (code \(error.code)). This usually means the language pack isn't downloaded yet — retry to trigger the system download prompt, or check Settings > Apps > Translate > Translation Languages."
        }
        return error.localizedDescription
    }

    func speak(_ text: String, language: AppLanguage) {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.speechSynthesisVoiceLanguage)
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }

    func pronunciation(for text: String, language: AppLanguage) -> String? {
        Transliteration.pronunciation(for: text, language: language)
    }
}

extension DateFormatter {
    static let diagnosticsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
