import Foundation

public struct SessionPrompt: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let cardID: UUID
    public let reference: String
    public let promptText: String
    public let maskedWords: [String]

    public init(card: MemorizationCard, translation: Translation, reviewLevel: ReviewLevel) {
        self.id = card.id
        self.cardID = card.id
        self.reference = card.verse.reference.formatted(for: translation)
        self.promptText = card.verse.text(for: translation)
        self.maskedWords = Self.makeMask(from: card.verse.text(for: translation), reviewLevel: reviewLevel)
    }

    private static func makeMask(from text: String, reviewLevel: ReviewLevel) -> [String] {
        let tokens = text.split(separator: " ").map(String.init)

        switch reviewLevel {
        case .standard:
            return tokens.enumerated().map { index, token in
                index.isMultiple(of: 3) ? "____" : token
            }
        case .medium:
            guard !tokens.isEmpty else { return [] }
            let hiddenCount = Int(ceil(Double(tokens.count) * 0.8))
            let hiddenIndexes = Set(randomizedIndexes(count: tokens.count, taking: hiddenCount, seedText: text))
            return tokens.enumerated().map { index, token in
                hiddenIndexes.contains(index) ? "____" : token
            }
        case .hard:
            return tokens.map { _ in "____" }
        }
    }

    private static func randomizedIndexes(count: Int, taking hiddenCount: Int, seedText: String) -> [Int] {
        guard count > 0, hiddenCount > 0 else { return [] }

        var indexes = Array(0..<count)
        var generator = SeededGenerator(seed: stableSeed(for: seedText))
        indexes.shuffle(using: &generator)
        return Array(indexes.prefix(min(hiddenCount, count))).sorted()
    }

    private static func stableSeed(for text: String) -> UInt64 {
        text.unicodeScalars.reduce(into: UInt64(1469598103934665603)) { seed, scalar in
            seed ^= UInt64(scalar.value)
            seed &*= 1099511628211
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
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
    public private(set) var passedPromptIDs: Set<UUID>
    public private(set) var startedAt: Date

    public init(cards: [MemorizationCard], translation: Translation, reviewLevel: ReviewLevel, startedAt: Date = .now) {
        self.prompts = cards.map { SessionPrompt(card: $0, translation: translation, reviewLevel: reviewLevel) }
        self.currentIndex = 0
        self.grades = []
        self.passedPromptIDs = []
        self.startedAt = startedAt
    }

    public var currentPrompt: SessionPrompt? {
        guard currentIndex < prompts.count else { return nil }
        return prompts[currentIndex]
    }

    public var isComplete: Bool {
        currentIndex >= prompts.count
    }

    public var canMoveToPreviousPrompt: Bool {
        currentIndex > 0 && !prompts.isEmpty
    }

    public var canMoveToNextPrompt: Bool {
        currentIndex < prompts.count - 1
    }

    public var passedCount: Int {
        passedPromptIDs.count
    }

    public mutating func record(grade: RecallGrade) {
        guard !isComplete else { return }
        grades.append(grade)
        currentIndex += 1
    }

    public mutating func moveToPreviousPrompt() {
        guard canMoveToPreviousPrompt else { return }
        currentIndex -= 1
    }

    public mutating func moveToNextPrompt() {
        guard canMoveToNextPrompt else { return }
        currentIndex += 1
    }

    public mutating func markPassed(cardID: UUID) {
        passedPromptIDs.insert(cardID)
    }

    public mutating func resetPassed(cardID: UUID) {
        passedPromptIDs.remove(cardID)
    }

    public func isPassed(cardID: UUID) -> Bool {
        passedPromptIDs.contains(cardID)
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
