import Foundation
import Observation

@MainActor
@Observable
public final class BibleMemorizeStore {
    public private(set) var cards: [MemorizationCard]
    public private(set) var collections: [MemorizationCollection]
    public private(set) var todaysSession: MemorizationSession?

    private let scheduler: MemorizationScheduler

    public init(
        cards: [MemorizationCard],
        collections: [MemorizationCollection],
        scheduler: MemorizationScheduler = MemorizationScheduler()
    ) {
        self.cards = cards
        self.collections = collections
        self.scheduler = scheduler
    }

    public convenience init() {
        self.init(
            cards: SampleData.seedCards,
            collections: SampleData.seedCollections
        )
    }

    public var dueCards: [MemorizationCard] {
        cards
            .filter { $0.nextReviewDate <= .now }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }

    public var upcomingCards: [MemorizationCard] {
        cards
            .filter { $0.nextReviewDate > .now }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }

    public func addVerse(
        reference: BibleReference,
        translation: Translation,
        text: String,
        tags: [String],
        difficulty: VerseDifficulty
    ) {
        let verse = MemoryVerse(
            reference: reference,
            translation: translation,
            text: text,
            tags: tags,
            difficulty: difficulty
        )

        cards.insert(MemorizationCard(verse: verse), at: 0)
    }

    public func startSession(limit: Int = 10) {
        let sessionCards = Array(dueCards.prefix(limit))
        todaysSession = MemorizationSession(cards: sessionCards)
    }

    @discardableResult
    public func submitGrade(
        for cardID: UUID,
        grade: RecallGrade,
        elapsedSeconds: TimeInterval
    ) -> SessionSummary? {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else {
            return todaysSession?.makeSummary()
        }

        let reviewedAt = Date()
        cards[index] = scheduler.updatedCard(
            from: cards[index],
            with: grade,
            reviewedAt: reviewedAt,
            elapsedSeconds: elapsedSeconds
        )

        todaysSession?.record(grade: grade)

        guard let session = todaysSession, session.isComplete else {
            return nil
        }

        let summary = session.makeSummary(finishedAt: reviewedAt)
        todaysSession = nil
        return summary
    }
}
