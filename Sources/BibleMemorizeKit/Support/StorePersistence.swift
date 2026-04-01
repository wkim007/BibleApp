import Foundation

struct StoreSnapshot: Codable {
    var cards: [MemorizationCard]
    var collections: [MemorizationCollection]
    var passedPromptIDs: Set<UUID>
    var selectedTranslation: Translation
    var preferredVoiceIdentifiersByTranslation: [Translation: String]
    var reviewLevel: ReviewLevel
    var speechRateMultiplier: Double
    var keepScreenAwake: Bool
    var openAIEnabled: Bool
    var openAIValidationState: OpenAIValidationState

    private enum CodingKeys: String, CodingKey {
        case cards
        case collections
        case passedPromptIDs
        case selectedTranslation
        case preferredVoiceIdentifiersByTranslation
        case reviewLevel
        case speechRateMultiplier
        case keepScreenAwake
        case openAIEnabled
        case openAIValidationState
    }

    init(
        cards: [MemorizationCard],
        collections: [MemorizationCollection],
        passedPromptIDs: Set<UUID>,
        selectedTranslation: Translation,
        preferredVoiceIdentifiersByTranslation: [Translation: String],
        reviewLevel: ReviewLevel,
        speechRateMultiplier: Double,
        keepScreenAwake: Bool,
        openAIEnabled: Bool,
        openAIValidationState: OpenAIValidationState
    ) {
        self.cards = cards
        self.collections = collections
        self.passedPromptIDs = passedPromptIDs
        self.selectedTranslation = selectedTranslation
        self.preferredVoiceIdentifiersByTranslation = preferredVoiceIdentifiersByTranslation
        self.reviewLevel = reviewLevel
        self.speechRateMultiplier = speechRateMultiplier
        self.keepScreenAwake = keepScreenAwake
        self.openAIEnabled = openAIEnabled
        self.openAIValidationState = openAIValidationState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cards = try container.decode([MemorizationCard].self, forKey: .cards)
        collections = try container.decode([MemorizationCollection].self, forKey: .collections)
        passedPromptIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .passedPromptIDs) ?? []
        selectedTranslation = try container.decode(Translation.self, forKey: .selectedTranslation)
        preferredVoiceIdentifiersByTranslation = try container.decodeIfPresent([Translation: String].self, forKey: .preferredVoiceIdentifiersByTranslation) ?? [:]
        reviewLevel = try container.decodeIfPresent(ReviewLevel.self, forKey: .reviewLevel) ?? .standard
        speechRateMultiplier = try container.decode(Double.self, forKey: .speechRateMultiplier)
        keepScreenAwake = try container.decodeIfPresent(Bool.self, forKey: .keepScreenAwake) ?? false
        openAIEnabled = try container.decode(Bool.self, forKey: .openAIEnabled)
        openAIValidationState = try container.decodeIfPresent(OpenAIValidationState.self, forKey: .openAIValidationState)
            ?? (openAIEnabled ? .idle : .off)
    }
}

enum StorePersistence {
    private static let fileName = "BibleMemorizeStore.json"

    static func loadSnapshot() -> StoreSnapshot? {
        guard let url = snapshotURL() else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(StoreSnapshot.self, from: data)
    }

    static func saveSnapshot(_ snapshot: StoreSnapshot) {
        guard let url = snapshotURL() else { return }

        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to save store snapshot: \(error)")
        }
    }

    private static func snapshotURL() -> URL? {
        let fileManager = FileManager.default
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return baseURL
            .appendingPathComponent("BibleMemorizeKit", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
