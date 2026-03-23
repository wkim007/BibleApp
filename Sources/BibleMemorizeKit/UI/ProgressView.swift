import SwiftUI
import Charts

public struct ProgressView: View {
    @Bindable var store: BibleMemorizeStore

    public init(store: BibleMemorizeStore) {
        self.store = store
    }

    private var masterySnapshots: [VerseMasterySnapshot] {
        store.cards
            .map { ProgressAnalytics.masteryScore(for: $0, translation: store.selectedTranslation) }
            .sorted { $0.masteryScore > $1.masteryScore }
    }

    private var reviewRecords: [ReviewRecord] {
        store.cards
            .flatMap(\.reviewHistory)
            .sorted { $0.reviewedAt > $1.reviewedAt }
    }

    private func reference(for verseID: UUID) -> String {
        store.cards
            .first(where: { $0.verse.id == verseID })?
            .verse.reference.formatted(for: store.selectedTranslation)
            ?? "Verse"
    }

    private var activity: [ReviewActivityPoint] {
        ProgressAnalytics.reviewActivity(from: reviewRecords, days: 7)
    }

    private var memorizedCount: Int {
        masterySnapshots.filter { $0.masteryScore >= 0.75 }.count
    }

    private var averageMastery: Double {
        guard !masterySnapshots.isEmpty else { return 0 }
        return masterySnapshots.map(\.masteryScore).reduce(0, +) / Double(masterySnapshots.count)
    }

    private var currentStreak: Int {
        ProgressAnalytics.currentStreakDays(from: reviewRecords)
    }

    private var longestStreak: Int {
        ProgressAnalytics.longestStreakDays(from: reviewRecords)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summarySection
                activitySection
                masterySection
                recentHistorySection
                historySection
            }
            .padding(20)
        }
        .navigationTitle("Progress")
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)

            HStack(spacing: 12) {
                ProgressStatCard(title: "Memorized", value: "\(memorizedCount)")
                ProgressStatCard(title: "Reviews", value: "\(reviewRecords.count)")
            }

            HStack(spacing: 12) {
                ProgressStatCard(title: "Streak", value: "\(currentStreak)d")
                ProgressStatCard(title: "Mastery", value: "\(Int(averageMastery * 100))%")
            }

            Text("Longest streak: \(longestStreak) day\(longestStreak == 1 ? "" : "s")")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review Activity")
                .font(.headline)

            Chart(activity) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Reviews", point.reviewCount)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(6)
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading)
            }

            Text("Last 7 days of review activity.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var masterySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-Verse Mastery")
                .font(.headline)

            Chart(masterySnapshots.prefix(6)) { snapshot in
                BarMark(
                    x: .value("Mastery", snapshot.masteryScore),
                    y: .value("Verse", snapshot.reference)
                )
                .foregroundStyle(by: .value("Mastery", snapshot.masteryScore))
                .cornerRadius(6)
            }
            .frame(height: CGFloat(max(180, masterySnapshots.prefix(6).count * 44)))
            .chartXScale(domain: 0...1)
            .chartXAxis {
                AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text("\(Int(number * 100))%")
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mastery Snapshot")
                .font(.headline)

            ForEach(Array(masterySnapshots.prefix(5))) { snapshot in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.reference)
                            .font(.headline)
                        Text("\(snapshot.reviewCount) review\(snapshot.reviewCount == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(snapshot.masteryScore * 100))%")
                            .font(.headline)
                        if let lastReviewedAt = snapshot.lastReviewedAt {
                            Text(lastReviewedAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var recentHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Reviews")
                .font(.headline)

            ForEach(Array(reviewRecords.prefix(6))) { record in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reference(for: record.verseID))
                            .font(.headline)
                        Text(record.reviewedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(gradeLabel(record.grade))
                            .font(.subheadline.weight(.semibold))
                        Text("\(Int(record.elapsedSeconds))s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func gradeLabel(_ grade: RecallGrade) -> String {
        switch grade {
        case .completeBlackout:
            return "Blackout"
        case .difficult:
            return "Hard"
        case .hesitant:
            return "Hesitant"
        case .correct:
            return "Correct"
        case .effortless:
            return "Easy"
        }
    }
}

private struct ProgressStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
