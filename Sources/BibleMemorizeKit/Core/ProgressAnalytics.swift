import Foundation

public struct ReviewActivityPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let reviewCount: Int

    public init(date: Date, reviewCount: Int) {
        self.date = date
        self.reviewCount = reviewCount
    }
}

public struct VerseMasterySnapshot: Identifiable, Sendable {
    public let id: UUID
    public let reference: String
    public let masteryScore: Double
    public let reviewCount: Int
    public let lastReviewedAt: Date?

    public init(
        id: UUID,
        reference: String,
        masteryScore: Double,
        reviewCount: Int,
        lastReviewedAt: Date?
    ) {
        self.id = id
        self.reference = reference
        self.masteryScore = masteryScore
        self.reviewCount = reviewCount
        self.lastReviewedAt = lastReviewedAt
    }
}

public enum ProgressAnalytics {
    public static func masteryScore(for card: MemorizationCard, translation: Translation) -> VerseMasterySnapshot {
        let reviewCount = card.reviewHistory.count
        let reviewStrength = min(1.0, Double(reviewCount) / 6.0)
        let consistencyStrength = min(1.0, Double(card.consecutiveSuccesses) / 4.0)
        let intervalStrength = min(1.0, card.intervalDays / 14.0)
        let lapsePenalty = min(0.25, Double(card.lapses) * 0.05)
        let score = max(
            0,
            min(1, (reviewStrength * 0.35) + (consistencyStrength * 0.4) + (intervalStrength * 0.25) - lapsePenalty)
        )

        return VerseMasterySnapshot(
            id: card.id,
            reference: card.verse.reference.formatted(for: translation),
            masteryScore: score,
            reviewCount: reviewCount,
            lastReviewedAt: card.lastReviewedAt
        )
    }

    public static func currentStreakDays(from records: [ReviewRecord], calendar: Calendar = .current) -> Int {
        let distinctDays = distinctReviewDays(from: records, calendar: calendar)
        guard let latest = distinctDays.first else { return 0 }

        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        guard latest == today || latest == yesterday else { return 0 }

        var streak = 1
        var cursor = latest

        while let previous = calendar.date(byAdding: .day, value: -1, to: cursor),
              distinctDays.contains(previous) {
            streak += 1
            cursor = previous
        }

        return streak
    }

    public static func longestStreakDays(from records: [ReviewRecord], calendar: Calendar = .current) -> Int {
        let days = distinctReviewDays(from: records, calendar: calendar).sorted()
        guard !days.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for index in 1..<days.count {
            let previous = days[index - 1]
            let currentDay = days[index]
            if calendar.dateComponents([.day], from: previous, to: currentDay).day == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    public static func reviewActivity(
        from records: [ReviewRecord],
        days: Int,
        calendar: Calendar = .current
    ) -> [ReviewActivityPoint] {
        let today = calendar.startOfDay(for: .now)
        let dailyCounts = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.reviewedAt)
        }.mapValues(\.count)

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today) else {
                return nil
            }
            return ReviewActivityPoint(date: date, reviewCount: dailyCounts[date, default: 0])
        }
    }

    private static func distinctReviewDays(from records: [ReviewRecord], calendar: Calendar) -> [Date] {
        Array(Set(records.map { calendar.startOfDay(for: $0.reviewedAt) }))
            .sorted(by: >)
    }
}
