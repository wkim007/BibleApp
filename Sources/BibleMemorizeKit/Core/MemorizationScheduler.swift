import Foundation

public struct MemorizationScheduler: Sendable {
    public init() {}

    public func updatedCard(
        from card: MemorizationCard,
        with grade: RecallGrade,
        reviewedAt: Date = .now,
        elapsedSeconds: TimeInterval
    ) -> MemorizationCard {
        var updated = card
        let newRecord = ReviewRecord(
            verseID: card.verse.id,
            reviewedAt: reviewedAt,
            grade: grade,
            elapsedSeconds: elapsedSeconds
        )

        updated.lastReviewedAt = reviewedAt
        updated.reviewHistory.append(newRecord)

        if grade.rawValue < RecallGrade.hesitant.rawValue {
            updated.consecutiveSuccesses = 0
            updated.lapses += 1
            updated.intervalDays = 1
            updated.easeFactor = max(1.3, updated.easeFactor - 0.2)
        } else {
            updated.consecutiveSuccesses += 1
            updated.easeFactor = max(
                1.3,
                updated.easeFactor + 0.1 - Double(4 - grade.rawValue) * 0.08
            )

            switch updated.consecutiveSuccesses {
            case 1:
                updated.intervalDays = 1
            case 2:
                updated.intervalDays = 3
            default:
                updated.intervalDays = max(1, updated.intervalDays * updated.easeFactor)
            }
        }

        updated.nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: max(1, Int(updated.intervalDays.rounded())),
            to: reviewedAt
        ) ?? reviewedAt

        return updated
    }
}
