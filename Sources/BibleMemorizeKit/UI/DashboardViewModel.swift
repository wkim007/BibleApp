import Foundation
import Observation

@MainActor
@Observable
public final class DashboardViewModel {
    public private(set) var store: BibleMemorizeStore

    public init(store: BibleMemorizeStore) {
        self.store = store
    }

    public convenience init() {
        self.init(store: BibleMemorizeStore())
    }

    public var dueCount: Int {
        store.dueCards.count
    }

    public var streakEstimate: Int {
        store.cards.reduce(into: 0) { result, card in
            if card.consecutiveSuccesses >= 2 {
                result += 1
            }
        }
    }

    public var reviewCompletion: Double {
        let total = store.cards.count
        guard total > 0 else { return 0 }
        return Double(total - store.dueCards.count) / Double(total)
    }
}
