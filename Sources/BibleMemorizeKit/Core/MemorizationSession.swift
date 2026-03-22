import Foundation

public struct SessionPrompt: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let cardID: UUID
    public let reference: String
    public let promptText: String
    public let maskedWords: [String]

    public init(card: MemorizationCard) {
        self.id = card.id
        self.cardID = card.id
        self.reference = card.verse.reference.formatted
        self.promptText = card.verse.text
        self.maskedWords = Self.makeMask(from: card.verse.text)
    }

    private static func makeMask(from text: String) -> [String] {
        text
            .split(separator: " ")
            .enumerated()
            .map { index, token in
                index.isMultiple(of: 3) ? "____" : String(token)
            }
    }
}

public struct SessionSummary: Sendable {
    public let reviewedCount: Int
    public let averageScore: Double
    public let totalDuration: TimeInterval

    public init(reviewedCount: Int, averageScore: Double, totalDuration: TimeInterval) {
        self.reviewedCount = reviewedCount
        self.averageScore = averageScore
        self.totalDuration = totalDuration
    }
}

public struct MemorizationSession: Sendable {
    public private(set) var prompts: [SessionPrompt]
    public private(set) var currentIndex: Int
    public private(set) var grades: [RecallGrade]
    public private(set) var startedAt: Date

    public init(cards: [MemorizationCard], startedAt: Date = .now) {
        self.prompts = cards.map(SessionPrompt.init)
        self.currentIndex = 0
        self.grades = []
        self.startedAt = startedAt
    }

    public var currentPrompt: SessionPrompt? {
        guard currentIndex < prompts.count else { return nil }
        return prompts[currentIndex]
    }

    public var isComplete: Bool {
        currentIndex >= prompts.count
    }

    public mutating func record(grade: RecallGrade) {
        guard !isComplete else { return }
        grades.append(grade)
        currentIndex += 1
    }

    public func makeSummary(finishedAt: Date = .now) -> SessionSummary {
        let average = grades.isEmpty
            ? 0
            : Double(grades.map(\.rawValue).reduce(0, +)) / Double(grades.count)

        return SessionSummary(
            reviewedCount: grades.count,
            averageScore: average,
            totalDuration: finishedAt.timeIntervalSince(startedAt)
        )
    }
}
