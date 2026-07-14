import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct DictionarySense: Identifiable {
    let id = UUID()
    let pos: String
    let glossRu: String
    let glossDe: String
    let examples: [String]
    let synonyms: [String]

    var hasCuratedTranslation: Bool { !glossRu.isEmpty }
    var displayGloss: String { hasCuratedTranslation ? glossRu : glossDe }
}

struct DictionaryEntry {
    let headword: String
    let senses: [DictionarySense]
}

/// Reads GermanDictionary.sqlite, built offline by build_german_dictionary.py
/// from the German Wiktionary (kaikki.org / Wiktextract dump, CC-BY-SA/GFDL).
/// Entirely local: no network access, ever.
final class GermanDictionary {
    static let shared = GermanDictionary()

    private var db: OpaquePointer?

    private init() {
        guard let url = Bundle.main.url(forResource: "GermanDictionary", withExtension: "sqlite") else {
            assertionFailure("GermanDictionary.sqlite is missing from the app bundle — run build_german_dictionary.py and add it to the target.")
            return
        }
        // Read-only + immutable: the bundled file never changes at runtime,
        // which lets SQLite skip locking machinery entirely.
        let uri = "file:\(url.path)?immutable=1"
        if sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) != SQLITE_OK {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            assertionFailure("Failed to open GermanDictionary.sqlite: \(message)")
        }
    }

    deinit {
        sqlite3_close(db)
    }

    /// Looks up a word, following inflected forms back to their lemma
    /// (e.g. "gefahren" -> "fahren") when there's no direct entry.
    func lookup(_ rawWord: String) -> DictionaryEntry? {
        let word = rawWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return nil }

        if let entry = fetchEntry(headword: word) {
            return entry
        }
        if let lemma = fetchLemma(form: word), lemma.lowercased() != word.lowercased() {
            return fetchEntry(headword: lemma)
        }
        return nil
    }

    private func fetchEntry(headword: String) -> DictionaryEntry? {
        let sql = "SELECT headword, pos, gloss_ru, gloss_de, examples_json, synonyms_json FROM senses WHERE headword_lower = ? ORDER BY id"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, headword.lowercased(), -1, SQLITE_TRANSIENT)

        var senses: [DictionarySense] = []
        var actualHeadword = headword

        while sqlite3_step(statement) == SQLITE_ROW {
            actualHeadword = string(statement, 0)
            let pos = string(statement, 1)
            let glossRu = string(statement, 2)
            let glossDe = string(statement, 3)
            let examples = decodeStringArray(string(statement, 4))
            let synonyms = decodeStringArray(string(statement, 5))
            senses.append(DictionarySense(pos: pos, glossRu: glossRu, glossDe: glossDe, examples: examples, synonyms: synonyms))
        }

        guard !senses.isEmpty else { return nil }
        return DictionaryEntry(headword: actualHeadword, senses: senses)
    }

    private func fetchLemma(form: String) -> String? {
        let sql = "SELECT lemma FROM forms WHERE form_lower = ? LIMIT 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, form.lowercased(), -1, SQLITE_TRANSIENT)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return string(statement, 0)
    }

    private func string(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cString)
    }

    private func decodeStringArray(_ jsonText: String) -> [String] {
        guard let data = jsonText.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}