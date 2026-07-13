import Foundation

enum Transliteration {
    private static let cyrillicMap: [Character: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "yo",
        "ж": "zh", "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m",
        "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
        "ф": "f", "х": "kh", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "shch",
        "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya"
    ]

    static func pronunciation(for text: String, language: AppLanguage) -> String? {
        switch language {
        case .russian:
            return transliterateCyrillic(text)
        case .english, .german:
            return nil
        }
    }

    private static func transliterateCyrillic(_ text: String) -> String {
        var result = ""
        for character in text {
            let lower = Character(character.lowercased())
            if let mapped = cyrillicMap[lower] {
                if character.isUppercase, let first = mapped.first {
                    result += first.uppercased() + mapped.dropFirst()
                } else {
                    result += mapped
                }
            } else {
                result.append(character)
            }
        }
        return result
    }
}
