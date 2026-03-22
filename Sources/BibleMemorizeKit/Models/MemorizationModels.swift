import Foundation

public enum Translation: String, Codable, CaseIterable, Identifiable, Sendable {
    case niv = "NIV"
    case esv = "ESV"
    case kjv = "KJV"
    case nkjv = "NKJV"
    case nasb = "NASB"
    case nlt = "NLT"
    case csb = "CSB"

    public var id: String { rawValue }
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
}

public enum VerseDifficulty: String, Codable, CaseIterable, Identifiable, Sendable {
    case easy
    case medium
    case hard

    public var id: String { rawValue }
}

public struct MemoryVerse: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var reference: BibleReference
    public var translation: Translation
    public var text: String
    public var tags: [String]
    public var difficulty: VerseDifficulty
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        reference: BibleReference,
        translation: Translation,
        text: String,
        tags: [String] = [],
        difficulty: VerseDifficulty = .medium,
        createdAt: Date = .now
    ) {
        self.id = id
        self.reference = reference
        self.translation = translation
        self.text = text
        self.tags = tags
        self.difficulty = difficulty
        self.createdAt = createdAt
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
        self.intervalDays = intervalDays
        self.easeFactor = easeFactor
        self.consecutiveSuccesses = consecutiveSuccesses
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
        self.reviewHistory = reviewHistory
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
