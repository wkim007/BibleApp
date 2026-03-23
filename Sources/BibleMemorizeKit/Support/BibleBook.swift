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
        Self.allCases.first { $0.rawValue == name }
    }

    public func displayName(for translation: Translation) -> String {
        switch translation {
        case .korean:
            return Self.koreanNames[self] ?? rawValue
        default:
            return rawValue
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
}
