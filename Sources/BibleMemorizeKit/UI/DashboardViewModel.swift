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

    public var passCount: Int {
        store.cards.reduce(into: 0) { result, card in
            if card.consecutiveSuccesses >= 2 {
                result += 1
            }
        }
    }

    public var reviewCompletion: Double {
        let due = dueCount
        guard due > 0 else { return 1 }
        return min(Double(passCount) / Double(due), 1)
    }
}
