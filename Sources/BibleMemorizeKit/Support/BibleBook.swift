import Foundation

public enum BibleBook: String, CaseIterable, Identifiable, Codable, Sendable {
    case genesis = "Genesis"
    case exodus = "Exodus"
    case leviticus = "Leviticus"
    case numbers = "Numbers"
    case deuteronomy = "Deuteronomy"
    case joshua = "Joshua"
    case judges = "Judges"
    case ruth = "Ruth"
    case firstSamuel = "1 Samuel"
    case secondSamuel = "2 Samuel"
    case firstKings = "1 Kings"
    case secondKings = "2 Kings"
    case firstChronicles = "1 Chronicles"
    case secondChronicles = "2 Chronicles"
    case ezra = "Ezra"
    case nehemiah = "Nehemiah"
    case esther = "Esther"
    case job = "Job"
    case psalm = "Psalm"
    case proverbs = "Proverbs"
    case ecclesiastes = "Ecclesiastes"
    case songOfSolomon = "Song of Solomon"
    case isaiah = "Isaiah"
    case jeremiah = "Jeremiah"
    case lamentations = "Lamentations"
    case ezekiel = "Ezekiel"
    case daniel = "Daniel"
    case hosea = "Hosea"
    case joel = "Joel"
    case amos = "Amos"
    case obadiah = "Obadiah"
    case jonah = "Jonah"
    case micah = "Micah"
    case nahum = "Nahum"
    case habakkuk = "Habakkuk"
    case zephaniah = "Zephaniah"
    case haggai = "Haggai"
    case zechariah = "Zechariah"
    case malachi = "Malachi"
    case matthew = "Matthew"
    case mark = "Mark"
    case luke = "Luke"
    case john = "John"
    case acts = "Acts"
    case romans = "Romans"
    case firstCorinthians = "1 Corinthians"
    case secondCorinthians = "2 Corinthians"
    case galatians = "Galatians"
    case ephesians = "Ephesians"
    case philippians = "Philippians"
    case colossians = "Colossians"
    case firstThessalonians = "1 Thessalonians"
    case secondThessalonians = "2 Thessalonians"
    case firstTimothy = "1 Timothy"
    case secondTimothy = "2 Timothy"
    case titus = "Titus"
    case philemon = "Philemon"
    case hebrews = "Hebrews"
    case james = "James"
    case firstPeter = "1 Peter"
    case secondPeter = "2 Peter"
    case firstJohn = "1 John"
    case secondJohn = "2 John"
    case thirdJohn = "3 John"
    case jude = "Jude"
    case revelation = "Revelation"

    public var id: String { rawValue }

    public static func from(name: String) -> BibleBook? {
        let normalizedName = normalizeBookName(name)

        if let exactMatch = Self.allCases.first(where: { normalizeBookName($0.rawValue) == normalizedName }) {
            return exactMatch
        }

        if let koreanMatch = koreanNames.first(where: { normalizeBookName($0.value) == normalizedName }) {
            return koreanMatch.key
        }

        if let aliasMatch = englishAliases[normalizedName] {
            return aliasMatch
        }

        return nil
    }

    public var chapterCount: Int {
        chapterVerseCounts.count
    }

    public func verseCount(in chapter: Int) -> Int? {
        guard chapter >= 1, chapter <= chapterVerseCounts.count else { return nil }
        return chapterVerseCounts[chapter - 1]
    }

    public func displayName(for translation: Translation) -> String {
        switch translation {
        case .korean:
            return Self.koreanNames[self] ?? rawValue
        default:
            return rawValue
        }
    }

    private var chapterVerseCounts: [Int] {
        switch self {
        case .genesis: return [31, 25, 24, 26, 32, 22, 24, 22, 29, 32, 32, 20, 18, 24, 21, 16, 27, 33, 38, 18, 34, 24, 20, 67, 34, 35, 46, 22, 35, 43, 55, 32, 20, 31, 29, 43, 36, 30, 23, 23, 57, 38, 34, 34, 28, 34, 31, 22, 33, 26]
        case .exodus: return [22, 25, 22, 31, 23, 30, 25, 32, 35, 29, 10, 51, 22, 31, 27, 36, 16, 27, 25, 26, 36, 31, 33, 18, 40, 37, 21, 43, 46, 38, 18, 35, 23, 35, 35, 38, 29, 31, 43, 38]
        case .leviticus: return [17, 16, 17, 35, 19, 30, 38, 36, 24, 20, 47, 8, 59, 57, 33, 34, 16, 30, 37, 27, 24, 33, 44, 23, 55, 46, 34]
        case .numbers: return [54, 34, 51, 49, 31, 27, 89, 26, 23, 36, 35, 16, 33, 45, 41, 50, 13, 32, 22, 29, 35, 41, 30, 25, 18, 65, 23, 31, 39, 17, 54, 42, 56, 29, 34, 13]
        case .deuteronomy: return [46, 37, 29, 49, 33, 25, 26, 20, 29, 22, 32, 32, 18, 29, 23, 22, 20, 22, 21, 20, 23, 30, 25, 22, 19, 19, 26, 68, 29, 20, 30, 52, 29, 12]
        case .joshua: return [18, 24, 17, 24, 15, 27, 26, 35, 27, 43, 23, 24, 33, 15, 63, 10, 18, 28, 51, 9, 45, 34, 16, 33]
        case .judges: return [36, 23, 31, 24, 31, 40, 25, 35, 57, 18, 40, 15, 25, 20, 20, 31, 13, 31, 30, 48, 25]
        case .ruth: return [22, 23, 18, 22]
        case .firstSamuel: return [28, 36, 21, 22, 12, 21, 17, 22, 27, 27, 15, 25, 23, 52, 35, 23, 58, 30, 24, 42, 15, 23, 29, 22, 44, 25, 12, 25, 11, 31, 13]
        case .secondSamuel: return [27, 32, 39, 12, 25, 23, 29, 18, 13, 19, 27, 31, 39, 33, 37, 23, 29, 33, 43, 26, 22, 51, 39, 25]
        case .firstKings: return [53, 46, 28, 34, 18, 38, 51, 66, 28, 29, 43, 33, 34, 31, 34, 34, 24, 46, 21, 43, 29, 53]
        case .secondKings: return [18, 25, 27, 44, 27, 33, 20, 29, 37, 36, 21, 21, 25, 29, 38, 20, 41, 37, 37, 21, 26, 20, 37, 20, 30]
        case .firstChronicles: return [54, 55, 24, 43, 41, 66, 40, 40, 44, 14, 47, 40, 14, 17, 29, 43, 27, 17, 19, 8, 30, 19, 32, 31, 31, 32, 34, 21, 30]
        case .secondChronicles: return [17, 18, 17, 22, 14, 42, 22, 18, 31, 19, 23, 16, 22, 15, 19, 14, 19, 34, 11, 37, 20, 12, 21, 27, 28, 23, 9, 27, 36, 27, 21, 33, 25, 33, 27, 23]
        case .ezra: return [11, 70, 13, 24, 17, 22, 28, 36, 15, 44]
        case .nehemiah: return [11, 20, 32, 23, 19, 19, 73, 18, 38, 39, 36, 47, 31]
        case .esther: return [22, 23, 15, 17, 14, 14, 10, 17, 32, 3]
        case .job: return [22, 13, 26, 21, 27, 30, 21, 22, 35, 22, 20, 25, 28, 22, 35, 22, 16, 21, 29, 29, 34, 30, 17, 25, 6, 14, 23, 28, 25, 31, 40, 22, 33, 37, 16, 33, 24, 41, 30, 24, 34, 17]
        case .psalm: return [6, 12, 8, 8, 12, 10, 17, 9, 20, 18, 7, 8, 6, 7, 5, 11, 15, 50, 14, 9, 13, 31, 6, 10, 22, 12, 14, 9, 11, 12, 24, 11, 22, 22, 28, 12, 40, 22, 13, 17, 13, 11, 5, 26, 17, 11, 9, 14, 20, 23, 19, 9, 6, 7, 23, 13, 11, 11, 17, 12, 8, 12, 11, 10, 13, 20, 7, 35, 36, 5, 24, 20, 28, 23, 10, 12, 20, 72, 13, 19, 16, 8, 18, 12, 13, 17, 7, 18, 52, 17, 16, 15, 5, 23, 11, 13, 12, 9, 9, 5, 8, 28, 22, 35, 45, 48, 43, 13, 31, 7, 10, 10, 9, 8, 18, 19, 2, 29, 176, 7, 8, 9, 4, 8, 5, 6, 5, 6, 8, 8, 3, 18, 3, 3, 21, 26, 9, 8, 24, 13, 10, 7, 12, 15, 21, 10, 20, 14, 9, 6]
        case .proverbs: return [33, 22, 35, 27, 23, 35, 27, 36, 18, 32, 31, 28, 25, 35, 33, 33, 28, 24, 29, 30, 31, 29, 35, 34, 28, 28, 27, 28, 27, 33, 31]
        case .ecclesiastes: return [18, 26, 22, 16, 20, 12, 29, 17, 18, 20, 10, 14]
        case .songOfSolomon: return [17, 17, 11, 16, 16, 13, 13, 14]
        case .isaiah: return [31, 22, 26, 6, 30, 13, 25, 22, 21, 34, 16, 6, 22, 32, 9, 14, 14, 7, 25, 6, 17, 25, 18, 23, 12, 21, 13, 29, 24, 33, 9, 20, 24, 17, 10, 22, 38, 22, 8, 31, 29, 25, 28, 28, 25, 13, 15, 22, 26, 11, 23, 15, 12, 17, 13, 12, 21, 14, 21, 22, 11, 12, 19, 12, 25, 24]
        case .jeremiah: return [19, 37, 25, 31, 31, 30, 34, 22, 26, 25, 23, 17, 27, 22, 21, 21, 27, 23, 15, 18, 14, 30, 40, 10, 38, 24, 22, 17, 32, 24, 40, 44, 26, 22, 19, 32, 21, 28, 18, 16, 18, 22, 13, 30, 5, 28, 7, 47, 39, 46, 64, 34]
        case .lamentations: return [22, 22, 66, 22, 22]
        case .ezekiel: return [28, 10, 27, 17, 17, 14, 27, 18, 11, 22, 25, 28, 23, 23, 8, 63, 24, 32, 14, 49, 32, 31, 49, 27, 17, 21, 36, 26, 21, 26, 18, 32, 33, 31, 15, 38, 28, 23, 29, 49, 26, 20, 27, 31, 25, 24, 23, 35]
        case .daniel: return [21, 49, 30, 37, 31, 28, 28, 27, 27, 21, 45, 13]
        case .hosea: return [11, 23, 5, 19, 15, 11, 16, 14, 17, 15, 12, 14, 16, 9]
        case .joel: return [20, 32, 21]
        case .amos: return [15, 16, 15, 13, 27, 14, 17, 14, 15]
        case .obadiah: return [21]
        case .jonah: return [17, 10, 10, 11]
        case .micah: return [16, 13, 12, 13, 15, 16, 20]
        case .nahum: return [15, 13, 19]
        case .habakkuk: return [17, 20, 19]
        case .zephaniah: return [18, 15, 20]
        case .haggai: return [15, 23]
        case .zechariah: return [21, 13, 10, 14, 11, 15, 14, 23, 17, 12, 17, 14, 9, 21]
        case .malachi: return [14, 17, 18, 6]
        case .matthew: return [25, 23, 17, 25, 48, 34, 29, 34, 38, 42, 30, 50, 58, 36, 39, 28, 27, 35, 30, 34, 46, 46, 39, 51, 46, 75, 66, 20]
        case .mark: return [45, 28, 35, 41, 43, 56, 37, 38, 50, 52, 33, 44, 37, 72, 47, 20]
        case .luke: return [80, 52, 38, 44, 39, 49, 50, 56, 62, 42, 54, 59, 35, 35, 32, 31, 37, 43, 48, 47, 38, 71, 56, 53]
        case .john: return [51, 25, 36, 54, 47, 71, 53, 59, 41, 42, 57, 50, 38, 31, 27, 33, 26, 40, 42, 31, 25]
        case .acts: return [26, 47, 26, 37, 42, 15, 60, 40, 43, 48, 30, 25, 52, 28, 41, 40, 34, 28, 41, 38, 40, 30, 35, 27, 27, 32, 44, 31]
        case .romans: return [32, 29, 31, 25, 21, 23, 25, 39, 33, 21, 36, 21, 14, 23, 33, 27]
        case .firstCorinthians: return [31, 16, 23, 21, 13, 20, 40, 13, 27, 33, 34, 31, 13, 40, 58, 24]
        case .secondCorinthians: return [24, 17, 18, 18, 21, 18, 16, 24, 15, 18, 33, 21, 14]
        case .galatians: return [24, 21, 29, 31, 26, 18]
        case .ephesians: return [23, 22, 21, 32, 33, 24]
        case .philippians: return [30, 30, 21, 23]
        case .colossians: return [29, 23, 25, 18]
        case .firstThessalonians: return [10, 20, 13, 18, 28]
        case .secondThessalonians: return [12, 17, 18]
        case .firstTimothy: return [20, 15, 16, 16, 25, 21]
        case .secondTimothy: return [18, 26, 17, 22]
        case .titus: return [16, 15, 15]
        case .philemon: return [25]
        case .hebrews: return [14, 18, 19, 16, 14, 20, 28, 13, 28, 39, 40, 29, 25]
        case .james: return [27, 26, 18, 17, 20]
        case .firstPeter: return [25, 25, 22, 19, 14]
        case .secondPeter: return [21, 22, 18]
        case .firstJohn: return [10, 29, 24, 21, 21]
        case .secondJohn: return [13]
        case .thirdJohn: return [14]
        case .jude: return [25]
        case .revelation: return [20, 29, 22, 11, 14, 17, 17, 13, 21, 11, 19, 17, 18, 20, 8, 21, 18, 24, 21, 15, 27, 21]
        }
    }

    private static let koreanNames: [BibleBook: String] = [
        .genesis: "창세기",
        .exodus: "출애굽기",
        .leviticus: "레위기",
        .numbers: "민수기",
        .deuteronomy: "신명기",
        .joshua: "여호수아",
        .judges: "사사기",
        .ruth: "룻기",
        .firstSamuel: "사무엘상",
        .secondSamuel: "사무엘하",
        .firstKings: "열왕기상",
        .secondKings: "열왕기하",
        .firstChronicles: "역대상",
        .secondChronicles: "역대하",
        .ezra: "에스라",
        .nehemiah: "느헤미야",
        .esther: "에스더",
        .job: "욥기",
        .psalm: "시편",
        .proverbs: "잠언",
        .ecclesiastes: "전도서",
        .songOfSolomon: "아가",
        .isaiah: "이사야",
        .jeremiah: "예레미야",
        .lamentations: "예레미야애가",
        .ezekiel: "에스겔",
        .daniel: "다니엘",
        .hosea: "호세아",
        .joel: "요엘",
        .amos: "아모스",
        .obadiah: "오바댜",
        .jonah: "요나",
        .micah: "미가",
        .nahum: "나훔",
        .habakkuk: "하박국",
        .zephaniah: "스바냐",
        .haggai: "학개",
        .zechariah: "스가랴",
        .malachi: "말라기",
        .matthew: "마태복음",
        .mark: "마가복음",
        .luke: "누가복음",
        .john: "요한복음",
        .acts: "사도행전",
        .romans: "로마서",
        .firstCorinthians: "고린도전서",
        .secondCorinthians: "고린도후서",
        .galatians: "갈라디아서",
        .ephesians: "에베소서",
        .philippians: "빌립보서",
        .colossians: "골로새서",
        .firstThessalonians: "데살로니가전서",
        .secondThessalonians: "데살로니가후서",
        .firstTimothy: "디모데전서",
        .secondTimothy: "디모데후서",
        .titus: "디도서",
        .philemon: "빌레몬서",
        .hebrews: "히브리서",
        .james: "야고보서",
        .firstPeter: "베드로전서",
        .secondPeter: "베드로후서",
        .firstJohn: "요한일서",
        .secondJohn: "요한이서",
        .thirdJohn: "요한삼서",
        .jude: "유다서",
        .revelation: "요한계시록"
    ]

    private static let englishAliases: [String: BibleBook] = [
        "psalms": .psalm,
        "song of songs": .songOfSolomon
    ]

    private static func normalizeBookName(_ name: String) -> String {
        name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
