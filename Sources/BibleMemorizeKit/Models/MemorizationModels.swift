import Foundation

public enum Translation: String, Codable, CaseIterable, Identifiable, Sendable {
    case kjv = "KJV"
    case nkjv = "NKJV"
    case korean = "개역한글"
    case chinese = "中文"
    case spanish = "Español"
    case japanese = "日本語"
    case german = "Deutsch"

    public var id: String { rawValue }

    public var speechLanguageCode: String {
        switch self {
        case .kjv, .nkjv:
            return "en-US"
        case .korean:
            return "ko-KR"
        case .chinese:
            return "zh-CN"
        case .spanish:
            return "es-ES"
        case .japanese:
            return "ja-JP"
        case .german:
            return "de-DE"
        }
    }
}

public struct BibleReference: Codable, Hashable, Sendable {
    public let book: String
    public let chapter: Int
    public let verseStart: Int
    public let verseEnd: Int?

    public init(book: String, chapter: Int, verseStart: Int, verseEnd: Int? = nil) {
        self.book = book
        self.chapter = chapter
        self.verseStart = verseStart
        self.verseEnd = verseEnd
    }

    public var formatted: String {
        if let verseEnd, verseEnd != verseStart {
            return "\(book) \(chapter):\(verseStart)-\(verseEnd)"
        }
        return "\(book) \(chapter):\(verseStart)"
    }

    public func formatted(for translation: Translation) -> String {
        let localizedBook = Self.localizedBookName(book, for: translation)
        if let verseEnd, verseEnd != verseStart {
            return "\(localizedBook) \(chapter):\(verseStart)-\(verseEnd)"
        }
        return "\(localizedBook) \(chapter):\(verseStart)"
    }

    private static func localizedBookName(_ book: String, for translation: Translation) -> String {
        BibleBook.from(name: book)?.displayName(for: translation) ?? book
    }
}

public enum VerseDifficulty: String, Codable, CaseIterable, Identifiable, Sendable {
    case easy
    case medium
    case hard

    public var id: String { rawValue }
}

public enum VerseAssignmentType: String, Codable, CaseIterable, Identifiable, Sendable {
    case dueNow = "Due Now"
    case upcoming = "Upcoming"

    public var id: String { rawValue }
}

public struct MemoryVerse: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var reference: BibleReference
    public var defaultTranslation: Translation
    public var textsByTranslation: [Translation: String]
    public var tags: [String]
    public var difficulty: VerseDifficulty
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        reference: BibleReference,
        defaultTranslation: Translation = .nkjv,
        textsByTranslation: [Translation: String],
        tags: [String] = [],
        difficulty: VerseDifficulty = .medium,
        createdAt: Date = .now
    ) {
        self.id = id
        self.reference = reference
        self.defaultTranslation = defaultTranslation
        self.textsByTranslation = textsByTranslation
        self.tags = tags
        self.difficulty = difficulty
        self.createdAt = createdAt
    }

    public func text(for translation: Translation) -> String {
        textsByTranslation[translation]
            ?? textsByTranslation[defaultTranslation]
            ?? ""
    }
}

public enum RecallGrade: Int, Codable, CaseIterable, Identifiable, Sendable {
    case completeBlackout = 0
    case difficult = 1
    case hesitant = 2
    case correct = 3
    case effortless = 4

    public var id: Int { rawValue }
}

public struct ReviewRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let verseID: UUID
    public let reviewedAt: Date
    public let grade: RecallGrade
    public let elapsedSeconds: TimeInterval

    public init(
        id: UUID = UUID(),
        verseID: UUID,
        reviewedAt: Date = .now,
        grade: RecallGrade,
        elapsedSeconds: TimeInterval
    ) {
        self.id = id
        self.verseID = verseID
        self.reviewedAt = reviewedAt
        self.grade = grade
        self.elapsedSeconds = elapsedSeconds
    }
}

public struct MemorizationCard: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var verse: MemoryVerse
    public var nextReviewDate: Date
    public var sortOrder: Double
    public var intervalDays: Double
    public var easeFactor: Double
    public var consecutiveSuccesses: Int
    public var lapses: Int
    public var lastReviewedAt: Date?
    public var reviewHistory: [ReviewRecord]

    public init(
        id: UUID = UUID(),
        verse: MemoryVerse,
        nextReviewDate: Date = .now,
        sortOrder: Double = Date().timeIntervalSinceReferenceDate,
        intervalDays: Double = 0,
        easeFactor: Double = 2.5,
        consecutiveSuccesses: Int = 0,
        lapses: Int = 0,
        lastReviewedAt: Date? = nil,
        reviewHistory: [ReviewRecord] = []
    ) {
        self.id = id
        self.verse = verse
        self.nextReviewDate = nextReviewDate
        self.sortOrder = sortOrder
        self.intervalDays = intervalDays
        self.easeFactor = easeFactor
        self.consecutiveSuccesses = consecutiveSuccesses
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
        self.reviewHistory = reviewHistory
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case verse
        case nextReviewDate
        case sortOrder
        case intervalDays
        case easeFactor
        case consecutiveSuccesses
        case lapses
        case lastReviewedAt
        case reviewHistory
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        verse = try container.decode(MemoryVerse.self, forKey: .verse)
        nextReviewDate = try container.decode(Date.self, forKey: .nextReviewDate)
        sortOrder = try container.decodeIfPresent(Double.self, forKey: .sortOrder)
            ?? nextReviewDate.timeIntervalSinceReferenceDate
        intervalDays = try container.decode(Double.self, forKey: .intervalDays)
        easeFactor = try container.decode(Double.self, forKey: .easeFactor)
        consecutiveSuccesses = try container.decode(Int.self, forKey: .consecutiveSuccesses)
        lapses = try container.decode(Int.self, forKey: .lapses)
        lastReviewedAt = try container.decodeIfPresent(Date.self, forKey: .lastReviewedAt)
        reviewHistory = try container.decode([ReviewRecord].self, forKey: .reviewHistory)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(verse, forKey: .verse)
        try container.encode(nextReviewDate, forKey: .nextReviewDate)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(intervalDays, forKey: .intervalDays)
        try container.encode(easeFactor, forKey: .easeFactor)
        try container.encode(consecutiveSuccesses, forKey: .consecutiveSuccesses)
        try container.encode(lapses, forKey: .lapses)
        try container.encodeIfPresent(lastReviewedAt, forKey: .lastReviewedAt)
        try container.encode(reviewHistory, forKey: .reviewHistory)
    }
}

public struct MemorizationCollection: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var description: String
    public var verseIDs: [UUID]

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        verseIDs: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.verseIDs = verseIDs
    }
}
