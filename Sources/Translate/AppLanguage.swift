import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case russian
    case german

    var id: String { rawValue }

    var locale: Locale.Language {
        switch self {
        case .english: return Locale.Language(identifier: "en")
        case .russian: return Locale.Language(identifier: "ru")
        case .german: return Locale.Language(identifier: "de")
        }
    }

    var visionRecognitionCode: String {
        switch self {
        case .english: return "en-US"
        case .russian: return "ru-RU"
        case .german: return "de-DE"
        }
    }

    var speechRecognitionLocale: Locale {
        switch self {
        case .english: return Locale(identifier: "en-US")
        case .russian: return Locale(identifier: "ru-RU")
        case .german: return Locale(identifier: "de-DE")
        }
    }

    var speechSynthesisVoiceLanguage: String {
        switch self {
        case .english: return "en-US"
        case .russian: return "ru-RU"
        case .german: return "de-DE"
        }
    }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Russian"
        case .german: return "German"
        }
    }
}
