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

    var displayName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Russian"
        case .german: return "German"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .russian: return "🇷🇺"
        case .german: return "🇩🇪"
        }
    }
}
