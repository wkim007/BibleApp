import Foundation

struct StoreSnapshot: Codable {
    var cards: [MemorizationCard]
    var collections: [MemorizationCollection]
    var selectedTranslation: Translation
    var speechRateMultiplier: Double
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
