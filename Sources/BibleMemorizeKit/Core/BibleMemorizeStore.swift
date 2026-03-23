import Foundation
import Observation

@MainActor
@Observable
public final class BibleMemorizeStore {
    public private(set) var cards: [MemorizationCard] {
        didSet { persistState() }
    }
    public private(set) var collections: [MemorizationCollection] {
        didSet { persistState() }
    }
    public private(set) var todaysSession: MemorizationSession?
    public var selectedTranslation: Translation {
        didSet { persistState() }
    }
    public var speechRateMultiplier: Double {
        didSet { persistState() }
    }
    public var isOpenAIEnabled: Bool {
        didSet {
            if !isOpenAIEnabled {
                openAIValidationState = .off
            } else if openAIAPIKey.isEmpty {
                openAIValidationState = .idle
            }
            persistState()
        }
    }
    public var openAIAPIKey: String {
        didSet {
            KeychainStore.save(openAIAPIKey)
            if isOpenAIEnabled, oldValue != openAIAPIKey {
                openAIValidationState = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .idle : .idle
            }
        }
    }
    public private(set) var openAIValidationState: OpenAIValidationState
    public private(set) var openAIStatusMessage: String?

    private let scheduler: MemorizationScheduler
    private let openAIClient: OpenAIClient

    public init(
        cards: [MemorizationCard],
        collections: [MemorizationCollection],
        selectedTranslation: Translation = .nkjv,
        speechRateMultiplier: Double = 0.9,
        isOpenAIEnabled: Bool = false,
        openAIAPIKey: String = "",
        openAIValidationState: OpenAIValidationState = .off,
        scheduler: MemorizationScheduler = MemorizationScheduler(),
        openAIClient: OpenAIClient = OpenAIClient()
    ) {
        self.cards = cards
        self.collections = collections
        self.selectedTranslation = selectedTranslation
        self.speechRateMultiplier = speechRateMultiplier
        self.isOpenAIEnabled = isOpenAIEnabled
        self.openAIAPIKey = openAIAPIKey
        self.openAIValidationState = openAIValidationState
        self.openAIStatusMessage = nil
        self.scheduler = scheduler
        self.openAIClient = openAIClient
    }

    public convenience init() {
        if let snapshot = StorePersistence.loadSnapshot() {
            self.init(
                cards: snapshot.cards,
                collections: snapshot.collections,
                selectedTranslation: snapshot.selectedTranslation,
                speechRateMultiplier: snapshot.speechRateMultiplier,
                isOpenAIEnabled: snapshot.openAIEnabled,
                openAIAPIKey: KeychainStore.load(),
                openAIValidationState: snapshot.openAIEnabled ? .idle : .off
            )
        } else {
            self.init(
                cards: SampleData.seedCards,
                collections: SampleData.seedCollections,
                selectedTranslation: .nkjv,
                speechRateMultiplier: 0.9,
                isOpenAIEnabled: false,
                openAIAPIKey: KeychainStore.load(),
                openAIValidationState: .off
            )
        }
    }

    public var canUseOpenAI: Bool {
        isOpenAIEnabled && openAIValidationState == .valid && !openAIAPIKey.isEmpty
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

    public func deleteVerse(cardID: UUID) {
        cards.removeAll { $0.id == cardID }

        if let session = todaysSession {
            let remainingCards = session.prompts.compactMap { prompt in
                cards.first(where: { $0.id == prompt.cardID })
            }

            if remainingCards.isEmpty {
                todaysSession = nil
            } else {
                todaysSession = MemorizationSession(cards: remainingCards, translation: selectedTranslation)
            }
        }
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

    public func setOpenAIEnabled(_ isEnabled: Bool) {
        isOpenAIEnabled = isEnabled
    }

    public func validateOpenAIKey() async {
        guard isOpenAIEnabled else {
            openAIValidationState = .off
            openAIStatusMessage = "OpenAI mode is off."
            return
        }

        let trimmedKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            openAIValidationState = .invalid
            openAIStatusMessage = "Enter an API key first."
            return
        }

        openAIValidationState = .validating
        openAIStatusMessage = "Validating key..."

        do {
            try await openAIClient.validate(apiKey: trimmedKey)
            openAIValidationState = .valid
            openAIStatusMessage = "API key is valid."
        } catch OpenAIClientError.invalidAPIKey {
            openAIValidationState = .invalid
            openAIStatusMessage = "API key is invalid."
        } catch {
            openAIValidationState = .failed
            openAIStatusMessage = "Validation failed. Check your network and try again."
        }
    }

    public func fetchVerseTextWithAI(request: VerseLookupRequest) async throws -> String {
        guard canUseOpenAI else {
            throw OpenAIClientError.invalidAPIKey
        }

        return try await openAIClient.fetchVerseText(
            apiKey: openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            request: request
        )
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

    private func persistState() {
        StorePersistence.saveSnapshot(
            StoreSnapshot(
                cards: cards,
                collections: collections,
                selectedTranslation: selectedTranslation,
                speechRateMultiplier: speechRateMultiplier,
                openAIEnabled: isOpenAIEnabled
            )
        )
    }
}
