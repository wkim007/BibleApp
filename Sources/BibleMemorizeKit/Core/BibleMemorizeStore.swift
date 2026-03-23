import Foundation
import Observation

@MainActor
@Observable
public final class BibleMemorizeStore {
    public private(set) var cards: [MemorizationCard]
    public private(set) var collections: [MemorizationCollection]
    public private(set) var todaysSession: MemorizationSession?
    public var selectedTranslation: Translation
    public var speechRateMultiplier: Double

    private let scheduler: MemorizationScheduler

    public init(
        cards: [MemorizationCard],
        collections: [MemorizationCollection],
        selectedTranslation: Translation = .nkjv,
        speechRateMultiplier: Double = 1.0,
        scheduler: MemorizationScheduler = MemorizationScheduler()
    ) {
        self.cards = cards
        self.collections = collections
        self.selectedTranslation = selectedTranslation
        self.speechRateMultiplier = speechRateMultiplier
        self.scheduler = scheduler
    }

    public convenience init() {
        self.init(
            cards: SampleData.seedCards,
            collections: SampleData.seedCollections,
            selectedTranslation: .nkjv,
            speechRateMultiplier: 1.0
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
            defaultTranslation: translation,
            textsByTranslation: [translation: text],
            tags: tags,
            difficulty: difficulty
        )

        cards.insert(MemorizationCard(verse: verse), at: 0)
    }

    public func startSession(limit: Int = 10) {
        let sessionCards = Array(dueCards.prefix(limit))
        guard !sessionCards.isEmpty else {
            todaysSession = nil
            return
        }
        todaysSession = MemorizationSession(cards: sessionCards, translation: selectedTranslation)
    }

    public func toggleSession(limit: Int = 10) {
        if todaysSession == nil {
            startSession(limit: limit)
        } else {
            todaysSession = nil
        }
    }

    public func moveToPreviousSessionPrompt() {
        guard var session = todaysSession else { return }
        session.moveToPreviousPrompt()
        todaysSession = session
    }

    public func moveToNextSessionPrompt() {
        guard var session = todaysSession else { return }
        session.moveToNextPrompt()
        todaysSession = session
    }

    public func updateSelectedTranslation(_ translation: Translation) {
        selectedTranslation = translation
        if let session = todaysSession {
            let remainingCards = session.prompts.compactMap { prompt in
                cards.first(where: { $0.id == prompt.cardID })
            }
            todaysSession = MemorizationSession(cards: remainingCards, translation: translation)
        }
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
