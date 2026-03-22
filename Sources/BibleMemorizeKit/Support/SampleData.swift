import Foundation

public enum SampleData {
    public static let seedCards: [MemorizationCard] = [
        MemorizationCard(
            verse: MemoryVerse(
                reference: BibleReference(book: "Joshua", chapter: 1, verseStart: 9),
                translation: .niv,
                text: "Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.",
                tags: ["courage", "identity"],
                difficulty: .medium
            ),
            nextReviewDate: .now.addingTimeInterval(-3600),
            intervalDays: 1,
            easeFactor: 2.5,
            consecutiveSuccesses: 1
        ),
        MemorizationCard(
            verse: MemoryVerse(
                reference: BibleReference(book: "Romans", chapter: 12, verseStart: 2),
                translation: .esv,
                text: "Do not be conformed to this world, but be transformed by the renewal of your mind, that by testing you may discern what is the will of God, what is good and acceptable and perfect.",
                tags: ["mind", "renewal"],
                difficulty: .hard
            ),
            nextReviewDate: .now.addingTimeInterval(-7200),
            intervalDays: 3,
            easeFactor: 2.3,
            consecutiveSuccesses: 2
        ),
        MemorizationCard(
            verse: MemoryVerse(
                reference: BibleReference(book: "Psalm", chapter: 119, verseStart: 11),
                translation: .nkjv,
                text: "Your word I have hidden in my heart, that I might not sin against You.",
                tags: ["heart", "purity"],
                difficulty: .easy
            ),
            nextReviewDate: .now.addingTimeInterval(86400),
            intervalDays: 7,
            easeFactor: 2.7,
            consecutiveSuccesses: 4
        )
    ]

    public static let seedCollections: [MemorizationCollection] = [
        MemorizationCollection(
            title: "Foundation Verses",
            description: "A starter set covering courage, renewal, and devotion.",
            verseIDs: seedCards.map(\.verse.id)
        )
    ]
}
