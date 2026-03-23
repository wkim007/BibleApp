import Foundation

struct StoreSnapshot: Codable {
    var cards: [MemorizationCard]
    var collections: [MemorizationCollection]
    var passedPromptIDs: Set<UUID>
    var selectedTranslation: Translation
    var speechRateMultiplier: Double
    var openAIEnabled: Bool
    var openAIValidationState: OpenAIValidationState

    private enum CodingKeys: String, CodingKey {
        case cards
        case collections
        case passedPromptIDs
        case selectedTranslation
        case speechRateMultiplier
        case openAIEnabled
        case openAIValidationState
    }

    init(
        cards: [MemorizationCard],
        collections: [MemorizationCollection],
        passedPromptIDs: Set<UUID>,
        selectedTranslation: Translation,
        speechRateMultiplier: Double,
        openAIEnabled: Bool,
        openAIValidationState: OpenAIValidationState
    ) {
        self.cards = cards
        self.collections = collections
        self.passedPromptIDs = passedPromptIDs
        self.selectedTranslation = selectedTranslation
        self.speechRateMultiplier = speechRateMultiplier
        self.openAIEnabled = openAIEnabled
        self.openAIValidationState = openAIValidationState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cards = try container.decode([MemorizationCard].self, forKey: .cards)
        collections = try container.decode([MemorizationCollection].self, forKey: .collections)
        passedPromptIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .passedPromptIDs) ?? []
        selectedTranslation = try container.decode(Translation.self, forKey: .selectedTranslation)
        speechRateMultiplier = try container.decode(Double.self, forKey: .speechRateMultiplier)
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
