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
    public private(set) var passedPromptIDs: Set<UUID> {
        didSet { persistState() }
    }
    public var selectedTranslation: Translation {
        didSet { persistState() }
    }
    public var preferredVoiceIdentifiersByTranslation: [Translation: String] {
        didSet { persistState() }
    }
    public var reviewLevel: ReviewLevel {
        didSet {
            persistState()
            refreshSessionForCurrentSettings()
        }
    }
    public var speechRateMultiplier: Double {
        didSet { persistState() }
    }
    public var keepScreenAwake: Bool {
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
        passedPromptIDs: Set<UUID> = [],
        selectedTranslation: Translation = .nkjv,
        preferredVoiceIdentifiersByTranslation: [Translation: String] = [:],
        reviewLevel: ReviewLevel = .standard,
        speechRateMultiplier: Double = 0.9,
        keepScreenAwake: Bool = false,
        isOpenAIEnabled: Bool = false,
        openAIAPIKey: String = "",
        openAIValidationState: OpenAIValidationState = .off,
        scheduler: MemorizationScheduler = MemorizationScheduler(),
        openAIClient: OpenAIClient = OpenAIClient()
    ) {
        self.cards = cards
        self.collections = collections
        self.passedPromptIDs = passedPromptIDs
        self.selectedTranslation = selectedTranslation
        self.preferredVoiceIdentifiersByTranslation = preferredVoiceIdentifiersByTranslation
        self.reviewLevel = reviewLevel
        self.speechRateMultiplier = speechRateMultiplier
        self.keepScreenAwake = keepScreenAwake
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
                passedPromptIDs: snapshot.passedPromptIDs,
                selectedTranslation: snapshot.selectedTranslation,
                preferredVoiceIdentifiersByTranslation: snapshot.preferredVoiceIdentifiersByTranslation,
                reviewLevel: snapshot.reviewLevel,
                speechRateMultiplier: snapshot.speechRateMultiplier,
                keepScreenAwake: snapshot.keepScreenAwake,
                isOpenAIEnabled: snapshot.openAIEnabled,
                openAIAPIKey: KeychainStore.load(),
                openAIValidationState: snapshot.openAIEnabled ? snapshot.openAIValidationState : .off
            )
        } else {
            self.init(
                cards: SampleData.seedCards,
                collections: SampleData.seedCollections,
                passedPromptIDs: [],
                selectedTranslation: .nkjv,
                preferredVoiceIdentifiersByTranslation: [:],
                reviewLevel: .standard,
                speechRateMultiplier: 0.9,
                keepScreenAwake: false,
                isOpenAIEnabled: false,
                openAIAPIKey: KeychainStore.load(),
                openAIValidationState: .off
            )
        }
    }

    public var canUseOpenAI: Bool {
        isOpenAIEnabled && !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var dueCards: [MemorizationCard] {
        cards
            .filter { $0.nextReviewDate <= .now && $0.verse.defaultTranslation == selectedTranslation }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.nextReviewDate < rhs.nextReviewDate
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    public var upcomingCards: [MemorizationCard] {
        cards
            .filter { $0.nextReviewDate > .now && $0.verse.defaultTranslation == selectedTranslation }
            .sorted { lhs, rhs in
                if lhs.nextReviewDate == rhs.nextReviewDate {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.nextReviewDate < rhs.nextReviewDate
            }
    }

    public func assignmentType(for cardID: UUID) -> VerseAssignmentType {
        guard let card = cards.first(where: { $0.id == cardID }) else {
            return .dueNow
        }
        return card.nextReviewDate > .now ? .upcoming : .dueNow
    }

    public func addVerse(
        reference: BibleReference,
        translation: Translation,
        text: String,
        tags: [String],
        difficulty: VerseDifficulty,
        assignmentType: VerseAssignmentType = .dueNow
    ) {
        let verse = MemoryVerse(
            reference: reference,
            defaultTranslation: translation,
            textsByTranslation: [translation: text],
            tags: tags,
            difficulty: difficulty
        )

        var card = MemorizationCard(verse: verse)
        let placement = placement(for: assignmentType, excluding: nil)
        card.nextReviewDate = placement.nextReviewDate
        card.sortOrder = placement.sortOrder
        cards.insert(card, at: 0)
    }

    public func updateVerseText(cardID: UUID, translation: Translation, text: String) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        cards[index].verse.textsByTranslation[translation] = text
    }

    public func updateVerseBibleVersion(cardID: UUID, from oldTranslation: Translation, to newTranslation: Translation, text: String) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }

        cards[index].verse.defaultTranslation = newTranslation
        cards[index].verse.textsByTranslation[newTranslation] = text

        if oldTranslation != newTranslation,
           cards[index].verse.textsByTranslation[oldTranslation] == text {
            cards[index].verse.textsByTranslation.removeValue(forKey: oldTranslation)
        }

        rebuildSessionAfterCardStateChange()
    }

    public func updateAssignmentType(cardID: UUID, assignmentType: VerseAssignmentType) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        let placement = placement(for: assignmentType, excluding: cardID)
        cards[index].nextReviewDate = placement.nextReviewDate
        cards[index].sortOrder = placement.sortOrder
        if assignmentType == .upcoming {
            clearPassedState(for: cardID)
        }
        rebuildSessionAfterCardStateChange()
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
                todaysSession = MemorizationSession(cards: remainingCards, translation: selectedTranslation, reviewLevel: reviewLevel)
            }
        }
    }

    public func startSession(limit: Int = 10) {
        let sessionCards = Array(dueCards.prefix(limit))
        guard !sessionCards.isEmpty else {
            todaysSession = nil
            return
        }
        var session = MemorizationSession(cards: sessionCards, translation: selectedTranslation, reviewLevel: reviewLevel)
        for card in sessionCards where passedPromptIDs.contains(card.id) {
            session.markPassed(cardID: card.id)
        }
        todaysSession = session
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

    public func markPromptPassed(cardID: UUID) {
        passedPromptIDs.insert(cardID)
        guard var session = todaysSession else { return }
        session.markPassed(cardID: cardID)
        todaysSession = session
    }

    public func recordPassedReviewIfNeeded(cardID: UUID, elapsedSeconds: TimeInterval) {
        guard !passedPromptIDs.contains(cardID),
              let index = cards.firstIndex(where: { $0.id == cardID }) else {
            return
        }

        let existingNextReviewDate = cards[index].nextReviewDate
        let existingSortOrder = cards[index].sortOrder
        let reviewedAt = Date()

        var updatedCard = scheduler.updatedCard(
            from: cards[index],
            with: .effortless,
            reviewedAt: reviewedAt,
            elapsedSeconds: elapsedSeconds
        )
        updatedCard.nextReviewDate = existingNextReviewDate
        updatedCard.sortOrder = existingSortOrder
        cards[index] = updatedCard

        passedPromptIDs.insert(cardID)
        guard var session = todaysSession else { return }
        session.markPassed(cardID: cardID)
        todaysSession = session
    }

    public func resetPromptPassed(cardID: UUID) {
        passedPromptIDs.remove(cardID)
        guard var session = todaysSession else { return }
        session.resetPassed(cardID: cardID)
        todaysSession = session
    }

    public func isPromptPassed(_ cardID: UUID) -> Bool {
        passedPromptIDs.contains(cardID)
    }

    public func resetAllPassedPrompts() {
        passedPromptIDs.removeAll()
        if var session = todaysSession {
            for cardID in session.passedPromptIDs {
                session.resetPassed(cardID: cardID)
            }
            todaysSession = session
        }
    }

    public func resetProgressData() {
        passedPromptIDs.removeAll()
        todaysSession = nil

        for index in cards.indices {
            cards[index].intervalDays = 0
            cards[index].easeFactor = 2.5
            cards[index].consecutiveSuccesses = 0
            cards[index].lapses = 0
            cards[index].lastReviewedAt = nil
            cards[index].reviewHistory = []
        }
    }

    public func moveCardToUpcoming(cardID: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        guard cards[index].nextReviewDate <= .now else { return }

        let placement = placement(for: .upcoming, excluding: cardID)
        cards[index].nextReviewDate = placement.nextReviewDate
        cards[index].sortOrder = placement.sortOrder
        clearPassedState(for: cardID)
        rebuildSessionAfterCardStateChange()
    }

    public func moveCardToDueNow(cardID: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        guard cards[index].nextReviewDate > .now else { return }

        let placement = placement(for: .dueNow, excluding: cardID)
        cards[index].nextReviewDate = placement.nextReviewDate
        cards[index].sortOrder = placement.sortOrder
        rebuildSessionAfterCardStateChange()
    }

    public func reorderDueCard(cardID: UUID, before targetCardID: UUID) {
        let currentDue = dueCards
        guard let sourceIndex = currentDue.firstIndex(where: { $0.id == cardID }),
              let targetIndex = currentDue.firstIndex(where: { $0.id == targetCardID }),
              sourceIndex != targetIndex else {
            return
        }

        var reordered = currentDue
        let moved = reordered.remove(at: sourceIndex)
        let insertionIndex = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
        reordered.insert(moved, at: insertionIndex)

        for (index, card) in reordered.enumerated() {
            guard let storedIndex = cards.firstIndex(where: { $0.id == card.id }) else { continue }
            cards[storedIndex].sortOrder = Double(index + 1)
        }
    }

    public func updateSelectedTranslation(_ translation: Translation) {
        selectedTranslation = translation
        let remainingCards = dueCards
        if remainingCards.isEmpty {
            todaysSession = nil
        } else {
            var refreshedSession = MemorizationSession(cards: remainingCards, translation: translation, reviewLevel: reviewLevel)
            for card in remainingCards where passedPromptIDs.contains(card.id) {
                refreshedSession.markPassed(cardID: card.id)
            }
            todaysSession = refreshedSession
        }
    }

    public func preferredVoiceIdentifier(for translation: Translation) -> String? {
        preferredVoiceIdentifiersByTranslation[translation]
    }

    public func updatePreferredVoiceIdentifier(_ identifier: String?, for translation: Translation) {
        let trimmed = identifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            preferredVoiceIdentifiersByTranslation.removeValue(forKey: translation)
        } else {
            preferredVoiceIdentifiersByTranslation[translation] = trimmed
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

        let text = try await openAIClient.fetchVerseText(
            apiKey: openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            request: request
        )
        openAIValidationState = .valid
        openAIStatusMessage = "API key is valid."
        return text
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
                passedPromptIDs: passedPromptIDs,
                selectedTranslation: selectedTranslation,
                preferredVoiceIdentifiersByTranslation: preferredVoiceIdentifiersByTranslation,
                reviewLevel: reviewLevel,
                speechRateMultiplier: speechRateMultiplier,
                keepScreenAwake: keepScreenAwake,
                openAIEnabled: isOpenAIEnabled,
                openAIValidationState: openAIValidationState
            )
        )
    }

    private func placement(
        for assignmentType: VerseAssignmentType,
        excluding excludedCardID: UUID?
    ) -> (nextReviewDate: Date, sortOrder: Double) {
        switch assignmentType {
        case .dueNow:
            let earliestSortOrder = cards
                .filter { $0.id != excludedCardID && $0.nextReviewDate <= .now }
                .map(\.sortOrder)
                .min() ?? 1
            return (.now.addingTimeInterval(-1), earliestSortOrder - 1)
        case .upcoming:
            let latestUpcomingDate = cards
                .filter { $0.id != excludedCardID && $0.nextReviewDate > .now }
                .map(\.nextReviewDate)
                .max() ?? .now
            let latestUpcomingSortOrder = cards
                .filter { $0.id != excludedCardID && $0.nextReviewDate > .now }
                .map(\.sortOrder)
                .max() ?? Double(cards.count)
            let nextReviewDate = max(Date().addingTimeInterval(3600), latestUpcomingDate.addingTimeInterval(3600))
            return (nextReviewDate, latestUpcomingSortOrder + 1)
        }
    }

    private func rebuildSessionAfterCardStateChange() {
        guard let session = todaysSession else { return }

        let dueCardIDs = Set(cards.filter { $0.nextReviewDate <= .now }.map(\.id))
        let sessionCardIDs = Set(session.prompts.map(\.cardID))
        let combinedIDs = dueCardIDs.intersection(sessionCardIDs).union(dueCardIDs.subtracting(sessionCardIDs))
        let refreshedCards = dueCards.filter { combinedIDs.contains($0.id) }

        if refreshedCards.isEmpty {
            todaysSession = nil
            return
        }

        var refreshedSession = MemorizationSession(cards: refreshedCards, translation: selectedTranslation, reviewLevel: reviewLevel)
        for card in refreshedCards where passedPromptIDs.contains(card.id) {
            refreshedSession.markPassed(cardID: card.id)
        }
        todaysSession = refreshedSession
    }

    private func refreshSessionForCurrentSettings() {
        guard todaysSession != nil else { return }
        let remainingCards = dueCards
        if remainingCards.isEmpty {
            todaysSession = nil
            return
        }

        var refreshedSession = MemorizationSession(cards: remainingCards, translation: selectedTranslation, reviewLevel: reviewLevel)
        for card in remainingCards where passedPromptIDs.contains(card.id) {
            refreshedSession.markPassed(cardID: card.id)
        }
        todaysSession = refreshedSession
    }

    private func clearPassedState(for cardID: UUID) {
        passedPromptIDs.remove(cardID)
    }
}
