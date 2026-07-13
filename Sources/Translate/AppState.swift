import Foundation
import Translation
import Observation

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

    private var lastSource: AppLanguage?
    private var lastTarget: AppLanguage?

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

    func requestTranslation(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard sourceLanguage != targetLanguage else {
            log("Source and target languages must differ")
            return
        }

        pendingText = text
        translatedText = ""
        log("Requesting translation \(sourceLanguage.displayName) -> \(targetLanguage.displayName)")

        if var configuration, lastSource == sourceLanguage, lastTarget == targetLanguage {
            configuration.invalidate()
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
            log("ERROR domain=\(nsError.domain) code=\(nsError.code)")
            if !nsError.userInfo.isEmpty {
                log("userInfo=\(nsError.userInfo)")
            }
        }
    }
}

extension DateFormatter {
    static let diagnosticsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
