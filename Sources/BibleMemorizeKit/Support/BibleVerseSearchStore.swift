import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct BibleSearchResult: Identifiable, Hashable, Sendable {
    let id: Int64
    let translation: Translation
    let reference: BibleReference
    let verseText: String
    let canonicalBookName: String

    var formattedReference: String {
        reference.formatted(for: translation)
    }
}

enum BibleSearchVersion: String, CaseIterable, Identifiable {
    case korean = "개역한글"
    case english = "NKJV"
    case spanish = "Español"

    var id: String { rawValue }

    var translation: Translation {
        switch self {
        case .korean:
            return .korean
        case .english:
            return .nkjv
        case .spanish:
            return .spanish
        }
    }

    var databaseVersionCode: String {
        switch self {
        case .korean:
            return "KRV"
        case .english:
            return "NKJV"
        case .spanish:
            return "RVR1960"
        }
    }

    static func from(translation: Translation) -> BibleSearchVersion? {
        switch translation {
        case .korean:
            return .korean
        case .kjv, .nkjv:
            return .english
        case .spanish:
            return .spanish
        case .chinese, .japanese, .german:
            return nil
        }
    }
}

enum BibleVerseSearchStore {
    static func search(term: String, version: BibleSearchVersion, limit: Int = 200) throws -> [BibleSearchResult] {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else { return [] }
        guard let databaseURL = Bundle.module.url(forResource: "bible", withExtension: "db") else {
            throw SearchError.databaseNotFound
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let database else {
            throw SearchError.openFailed(message: sqliteMessage(from: database))
        }
        defer { sqlite3_close(database) }

        let sql = """
        SELECT
            verses.verse_id,
            book_titles.book_title,
            books.eng_full,
            verses.chapter_num,
            verses.verse_num,
            verse_texts.verse_text
        FROM verse_texts
        JOIN versions ON versions.version_id = verse_texts.version_id
        JOIN verses ON verses.verse_id = verse_texts.verse_id
        JOIN books ON books.book_id = verses.book_id
        JOIN book_titles
            ON book_titles.book_id = verses.book_id
            AND book_titles.version_id = versions.version_id
        WHERE versions.version_code = ?
          AND verse_texts.verse_text LIKE ?
        ORDER BY verses.verse_id
        LIMIT ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SearchError.prepareFailed(message: sqliteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, version.databaseVersionCode, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, "%\(trimmedTerm)%", -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 3, Int32(limit))

        var results: [BibleSearchResult] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let verseID = sqlite3_column_int64(statement, 0)
            let bookTitle = String(cString: sqlite3_column_text(statement, 1))
            let canonicalBookName = String(cString: sqlite3_column_text(statement, 2))
            let chapter = Int(sqlite3_column_int(statement, 3))
            let verse = Int(sqlite3_column_int(statement, 4))
            let text = String(cString: sqlite3_column_text(statement, 5))

            results.append(
                BibleSearchResult(
                    id: verseID,
                    translation: version.translation,
                    reference: BibleReference(book: bookTitle, chapter: chapter, verseStart: verse),
                    verseText: text,
                    canonicalBookName: canonicalBookName
                )
            )
        }

        return results
    }

    static func verseText(
        reference: BibleReference,
        translation: Translation
    ) throws -> String? {
        guard let version = BibleSearchVersion.from(translation: translation) else {
            return nil
        }
        guard let canonicalBookName = BibleBook.from(name: reference.book)?.rawValue else {
            return nil
        }
        guard let databaseURL = Bundle.module.url(forResource: "bible", withExtension: "db") else {
            throw SearchError.databaseNotFound
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let database else {
            throw SearchError.openFailed(message: sqliteMessage(from: database))
        }
        defer { sqlite3_close(database) }

        let sql = """
        SELECT verse_texts.verse_text
        FROM verse_texts
        JOIN versions ON versions.version_id = verse_texts.version_id
        JOIN verses ON verses.verse_id = verse_texts.verse_id
        JOIN books ON books.book_id = verses.book_id
        WHERE versions.version_code = ?
          AND books.eng_full = ?
          AND verses.chapter_num = ?
          AND verses.verse_num >= ?
          AND verses.verse_num <= ?
        ORDER BY verses.verse_num
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SearchError.prepareFailed(message: sqliteMessage(from: database))
        }
        defer { sqlite3_finalize(statement) }

        let verseEnd = reference.verseEnd ?? reference.verseStart
        sqlite3_bind_text(statement, 1, version.databaseVersionCode, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, canonicalBookName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 3, Int32(reference.chapter))
        sqlite3_bind_int(statement, 4, Int32(reference.verseStart))
        sqlite3_bind_int(statement, 5, Int32(verseEnd))

        var verseLines: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let cString = sqlite3_column_text(statement, 0) else { continue }
            verseLines.append(String(cString: cString))
        }

        guard !verseLines.isEmpty else {
            return nil
        }

        if verseLines.count == 1 {
            return verseLines[0]
        }

        return verseLines
            .map { verseLine in
                let trimmed = verseLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let lastCharacter = trimmed.last else { return trimmed }
                return [".", "!", "?"].contains(lastCharacter) ? trimmed : "\(trimmed)."
            }
            .joined(separator: " ")
    }

    private static func sqliteMessage(from database: OpaquePointer?) -> String {
        guard let database, let cString = sqlite3_errmsg(database) else {
            return "Unknown SQLite error"
        }
        return String(cString: cString)
    }
}

private enum SearchError: LocalizedError {
    case databaseNotFound
    case openFailed(message: String)
    case prepareFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "Bible database file was not found."
        case .openFailed(let message):
            return "Could not open the Bible database. \(message)"
        case .prepareFailed(let message):
            return "Could not prepare the Bible search query. \(message)"
        }
    }
}
