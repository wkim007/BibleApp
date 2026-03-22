import Foundation

public enum SampleData {
    public static let seedCards: [MemorizationCard] = [
        MemorizationCard(
            verse: MemoryVerse(
                reference: BibleReference(book: "Joshua", chapter: 1, verseStart: 9),
                defaultTranslation: .nkjv,
                textsByTranslation: [
                    .kjv: "Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the Lord thy God is with thee whithersoever thou goest.",
                    .nkjv: "Have I not commanded you? Be strong and of good courage; do not be afraid, nor be dismayed, for the Lord your God is with you wherever you go.",
                    .korean: "내가 네게 명령한 것이 아니냐 강하고 담대하라 두려워하지 말며 놀라지 말라 네가 어디로 가든지 네 하나님 여호와가 너와 함께 하느니라 하시니라."
                ],
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
                defaultTranslation: .nkjv,
                textsByTranslation: [
                    .kjv: "And be not conformed to this world: but be ye transformed by the renewing of your mind, that ye may prove what is that good, and acceptable, and perfect, will of God.",
                    .nkjv: "And do not be conformed to this world, but be transformed by the renewing of your mind, that you may prove what is that good and acceptable and perfect will of God.",
                    .korean: "너희는 이 세대를 본받지 말고 오직 마음을 새롭게 함으로 변화를 받아 하나님의 선하시고 기뻐하시고 온전하신 뜻이 무엇인지 분별하도록 하라."
                ],
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
                defaultTranslation: .nkjv,
                textsByTranslation: [
                    .kjv: "Thy word have I hid in mine heart, that I might not sin against thee.",
                    .nkjv: "Your word I have hidden in my heart, that I might not sin against You.",
                    .korean: "내가 주께 범죄하지 아니하려 하여 주의 말씀을 내 마음에 두었나이다."
                ],
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
