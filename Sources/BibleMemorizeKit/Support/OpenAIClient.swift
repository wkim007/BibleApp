import Foundation

public enum OpenAIValidationState: String, Codable, Sendable {
    case off
    case idle
    case validating
    case valid
    case invalid
    case failed
}

public struct VerseLookupRequest: Sendable {
    public let translation: Translation
    public let book: String
    public let chapter: Int
    public let verseStart: Int
    public let verseEnd: Int?

    public init(
        translation: Translation,
        book: String,
        chapter: Int,
        verseStart: Int,
        verseEnd: Int?
    ) {
        self.translation = translation
        self.book = book
        self.chapter = chapter
        self.verseStart = verseStart
        self.verseEnd = verseEnd
    }
}

enum OpenAIClientError: Error {
    case invalidAPIKey
    case invalidResponse
    case noOutput
}

public struct OpenAIClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    func validate(apiKey: String) async throws {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return
        case 401:
            throw OpenAIClientError.invalidAPIKey
        default:
            throw OpenAIClientError.invalidResponse
        }
    }

    func fetchVerseText(apiKey: String, request lookup: VerseLookupRequest) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let versePart: String
        if let verseEnd = lookup.verseEnd, verseEnd != lookup.verseStart {
            versePart = "\(lookup.verseStart)-\(verseEnd)"
        } else {
            versePart = "\(lookup.verseStart)"
        }

        let payload = ResponsesRequest(
            model: "gpt-5-mini",
            input: "Return only the exact verse text for \(lookup.translation.rawValue) \(lookup.book) \(lookup.chapter):\(versePart). Do not include the reference, explanation, quotes, headings, markdown, or any extra text."
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw OpenAIClientError.invalidAPIKey
        default:
            throw OpenAIClientError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ResponsesResponse.self, from: data)
        if let text = decoded.output
            .flatMap(\.content)
            .first(where: { $0.type == "output_text" })?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }

        throw OpenAIClientError.noOutput
    }
}

private struct ResponsesRequest: Codable {
    let model: String
    let input: String
}

private struct ResponsesResponse: Codable {
    let output: [ResponsesOutputItem]
}

private struct ResponsesOutputItem: Codable {
    let content: [ResponsesContentItem]
}

private struct ResponsesContentItem: Codable {
    let type: String
    let text: String?
}
