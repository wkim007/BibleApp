import Foundation

public enum SampleData {
    private static let joshuaVerseID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let romansVerseID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let psalmVerseID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    private static func dayOffset(_ days: Int, hour: Int = 9) -> Date {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: .now)
        let day = calendar.date(byAdding: .day, value: days, to: base) ?? .now
        return calendar.date(byAdding: .hour, value: hour, to: day) ?? day
    }

    public static let seedCards: [MemorizationCard] = [
        MemorizationCard(
            verse: MemoryVerse(
                id: joshuaVerseID,
                reference: BibleReference(book: "Joshua", chapter: 1, verseStart: 9),
                defaultTranslation: .nkjv,
                textsByTranslation: [
                    .kjv: "Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the Lord thy God is with thee whithersoever thou goest.",
                    .nkjv: "Have I not commanded you? Be strong and of good courage; do not be afraid, nor be dismayed, for the Lord your God is with you wherever you go.",
                    .korean: "내가 네게 명령한 것이 아니냐 강하고 담대하라 두려워하지 말며 놀라지 말라 네가 어디로 가든지 네 하나님 여호와가 너와 함께 하느니라 하시니라.",
                    .chinese: "我岂没有吩咐你吗？你当刚强壮胆，不要惧怕，也不要惊惶，因为你无论往哪里去，耶和华你的神必与你同在。",
                    .spanish: "Mira que te mando que te esfuerces y seas valiente; no temas ni desmayes, porque Jehova tu Dios estara contigo en dondequiera que vayas.",
                    .japanese: "わたしはあなたに命じたではないか。强くあれ。雄々しくあれ。恐れてはならない。おののいてはならない。あなたがどこへ行っても、あなたの神、主があなたと共にいるからである。",
                    .german: "Habe ich dir nicht geboten, stark und mutig zu sein? Erschrick nicht und furchte dich nicht; denn der Herr, dein Gott, ist mit dir, wohin du auch gehst."
                ],
                tags: ["courage", "identity"],
                difficulty: .medium
            ),
            nextReviewDate: .now.addingTimeInterval(-3600),
            sortOrder: 1,
            intervalDays: 1,
            easeFactor: 2.5,
            consecutiveSuccesses: 1,
            lapses: 1,
            lastReviewedAt: dayOffset(-1, hour: 20),
            reviewHistory: [
                ReviewRecord(verseID: joshuaVerseID, reviewedAt: dayOffset(-5), grade: .difficult, elapsedSeconds: 28),
                ReviewRecord(verseID: joshuaVerseID, reviewedAt: dayOffset(-3), grade: .hesitant, elapsedSeconds: 23),
                ReviewRecord(verseID: joshuaVerseID, reviewedAt: dayOffset(-1, hour: 20), grade: .correct, elapsedSeconds: 18)
            ]
        ),
        MemorizationCard(
            verse: MemoryVerse(
                id: romansVerseID,
                reference: BibleReference(book: "Romans", chapter: 12, verseStart: 2),
                defaultTranslation: .nkjv,
                textsByTranslation: [
                    .kjv: "And be not conformed to this world: but be ye transformed by the renewing of your mind, that ye may prove what is that good, and acceptable, and perfect, will of God.",
                    .nkjv: "And do not be conformed to this world, but be transformed by the renewing of your mind, that you may prove what is that good and acceptable and perfect will of God.",
                    .korean: "너희는 이 세대를 본받지 말고 오직 마음을 새롭게 함으로 변화를 받아 하나님의 선하시고 기뻐하시고 온전하신 뜻이 무엇인지 분별하도록 하라.",
                    .chinese: "不要效法这个世界，只要心意更新而变化，叫你们察验何为神善良、纯全、可喜悦的旨意。",
                    .spanish: "No os conforméis a este siglo, sino transformaos por medio de la renovacion de vuestro entendimiento, para que comprobeis cual sea la buena voluntad de Dios, agradable y perfecta.",
                    .japanese: "この世と調子を合わせてはいけません。むしろ、心を新たにして自分を変えていただき、神の御心は何か、すなわち何が良いことで、神に喜ばれ、完全であるのかをわきまえ知りなさい。",
                    .german: "Und gleicht euch nicht dieser Welt an, sondern lasst euch verwandeln durch die Erneuerung eures Sinnes, damit ihr prufen konnt, was der gute, wohlgefallige und vollkommene Wille Gottes ist."
                ],
                tags: ["mind", "renewal"],
                difficulty: .hard
            ),
            nextReviewDate: .now.addingTimeInterval(-7200),
            sortOrder: 2,
            intervalDays: 3,
            easeFactor: 2.3,
            consecutiveSuccesses: 2,
            lastReviewedAt: dayOffset(0, hour: 7),
            reviewHistory: [
                ReviewRecord(verseID: romansVerseID, reviewedAt: dayOffset(-6), grade: .hesitant, elapsedSeconds: 26),
                ReviewRecord(verseID: romansVerseID, reviewedAt: dayOffset(-4), grade: .correct, elapsedSeconds: 20),
                ReviewRecord(verseID: romansVerseID, reviewedAt: dayOffset(-2), grade: .correct, elapsedSeconds: 17),
                ReviewRecord(verseID: romansVerseID, reviewedAt: dayOffset(0, hour: 7), grade: .effortless, elapsedSeconds: 12)
            ]
        ),
        MemorizationCard(
            verse: MemoryVerse(
                id: psalmVerseID,
                reference: BibleReference(book: "Psalm", chapter: 119, verseStart: 11),
                defaultTranslation: .nkjv,
                textsByTranslation: [
                    .kjv: "Thy word have I hid in mine heart, that I might not sin against thee.",
                    .nkjv: "Your word I have hidden in my heart, that I might not sin against You.",
                    .korean: "내가 주께 범죄하지 아니하려 하여 주의 말씀을 내 마음에 두었나이다.",
                    .chinese: "我将你的话藏在心里，免得我得罪你。",
                    .spanish: "En mi corazon he guardado tus dichos, para no pecar contra ti.",
                    .japanese: "私はあなたに罪を犯さないため、あなたのことばを心に蓄えました。",
                    .german: "Ich bewahre dein Wort in meinem Herzen, damit ich nicht gegen dich sundige."
                ],
                tags: ["heart", "purity"],
                difficulty: .easy
            ),
            nextReviewDate: .now.addingTimeInterval(86400),
            sortOrder: 3,
            intervalDays: 7,
            easeFactor: 2.7,
            consecutiveSuccesses: 4,
            lastReviewedAt: dayOffset(0, hour: 6),
            reviewHistory: [
                ReviewRecord(verseID: psalmVerseID, reviewedAt: dayOffset(-6, hour: 18), grade: .correct, elapsedSeconds: 19),
                ReviewRecord(verseID: psalmVerseID, reviewedAt: dayOffset(-5, hour: 19), grade: .correct, elapsedSeconds: 17),
                ReviewRecord(verseID: psalmVerseID, reviewedAt: dayOffset(-4, hour: 19), grade: .effortless, elapsedSeconds: 13),
                ReviewRecord(verseID: psalmVerseID, reviewedAt: dayOffset(-3, hour: 19), grade: .effortless, elapsedSeconds: 11),
                ReviewRecord(verseID: psalmVerseID, reviewedAt: dayOffset(0, hour: 6), grade: .effortless, elapsedSeconds: 10)
            ]
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
