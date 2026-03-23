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
        do {
            return try await fetchVerseText(
                apiKey: apiKey,
                request: lookup,
                allowParaphraseFallback: false
            )
        } catch OpenAIClientError.noOutput {
            return try await fetchVerseText(
                apiKey: apiKey,
                request: lookup,
                allowParaphraseFallback: true
            )
        } catch OpenAIClientError.invalidResponse {
            return try await fetchVerseText(
                apiKey: apiKey,
                request: lookup,
                allowParaphraseFallback: true
            )
        }
    }

    private func fetchVerseText(
        apiKey: String,
        request lookup: VerseLookupRequest,
        allowParaphraseFallback: Bool
    ) async throws -> String {
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

        let prompt: String
        if allowParaphraseFallback {
            prompt = """
            Return a JSON object with one field named verse_text.
            Find the Bible verse for \(lookup.translation.rawValue) \(lookup.book) \(lookup.chapter):\(versePart).
            If exact copyrighted wording is not available, return a faithful translation or paraphrase in the requested language instead.
            Do not include the reference, notes, quotes, markdown, or any extra fields.
            """
        } else {
            prompt = """
            Return a JSON object with one field named verse_text.
            Provide the Bible verse text for \(lookup.translation.rawValue) \(lookup.book) \(lookup.chapter):\(versePart).
            Do not include the reference, notes, quotes, markdown, or any extra fields.
            """
        }

        let payload = ResponsesRequest(
            model: "gpt-5-mini",
            input: prompt,
            text: ResponseTextConfiguration(
                format: .jsonSchema(
                    JSONSchemaFormat(
                        name: "verse_lookup",
                        schema: [
                            "type": "object",
                            "additionalProperties": false,
                            "properties": [
                                "verse_text": [
                                    "type": "string"
                                ]
                            ],
                            "required": ["verse_text"]
                        ],
                        strict: true
                    )
                )
            )
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

        if let jsonText = decoded.output
            .flatMap(\.content)
            .first(where: { $0.type == "output_text" })?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           let verseText = extractVerseText(from: jsonText) {
            return verseText
        }

        if let text = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
           let verseText = extractVerseText(from: text) {
            return verseText
        }

        if let refusal = decoded.output
            .flatMap(\.content)
            .first(where: { $0.type == "refusal" })?.refusal?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !refusal.isEmpty {
            throw OpenAIClientError.noOutput
        }

        if let text = decoded.output
            .flatMap(\.content)
            .first(where: { $0.type == "output_text" })?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }

        throw OpenAIClientError.noOutput
    }

    private func extractVerseText(from text: String) -> String? {
        if let data = text.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(VerseLookupResult.self, from: data) {
            let trimmed = decoded.verseText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ResponsesRequest: Codable {
    let model: String
    let input: String
    let text: ResponseTextConfiguration?
}

private struct ResponsesResponse: Codable {
    let output: [ResponsesOutputItem]
    let outputText: String?

    private enum CodingKeys: String, CodingKey {
        case output
        case outputText = "output_text"
    }
}

private struct ResponsesOutputItem: Codable {
    let content: [ResponsesContentItem]
}

private struct ResponsesContentItem: Codable {
    let type: String
    let text: String?
    let refusal: String?
}

private struct ResponseTextConfiguration: Codable {
    let format: ResponseFormat
}

private enum ResponseFormat: Codable {
    case jsonSchema(JSONSchemaFormat)

    private enum CodingKeys: String, CodingKey {
        case type
        case name
        case schema
        case strict
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .jsonSchema(let format):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("json_schema", forKey: .type)
            try container.encode(format.name, forKey: .name)
            try container.encode(format.schema, forKey: .schema)
            try container.encode(format.strict, forKey: .strict)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == "json_schema" else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported response format type")
        }
        self = .jsonSchema(
            JSONSchemaFormat(
                name: try container.decode(String.self, forKey: .name),
                schema: try container.decode([String: JSONValue].self, forKey: .schema),
                strict: try container.decode(Bool.self, forKey: .strict)
            )
        )
    }
}

private struct JSONSchemaFormat {
    let name: String
    let schema: [String: JSONValue]
    let strict: Bool
}

private struct VerseLookupResult: Codable {
    let verseText: String

    private enum CodingKeys: String, CodingKey {
        case verseText = "verse_text"
    }
}

private enum JSONValue: Codable, ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral {
    case string(String)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])

    init(stringLiteral value: String) {
        self = .string(value)
    }

    init(booleanLiteral value: Bool) {
        self = .bool(value)
    }

    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }

    init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        }
    }
}
