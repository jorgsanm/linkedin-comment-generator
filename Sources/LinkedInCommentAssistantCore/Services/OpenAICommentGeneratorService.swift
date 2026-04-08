import Foundation

@MainActor
public protocol CommentGeneratorService {
    func generate(
        request: GenerationRequest,
        apiKey: String?,
        provider: ProviderSettings
    ) async throws -> [GeneratedCandidate]
}

@MainActor
public final class OpenAICommentGeneratorService: CommentGeneratorService {
    private let session: URLSession
    private let promptAssembler: PromptAssembler
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(
        session: URLSession = .shared,
        promptAssembler: PromptAssembler = PromptAssembler()
    ) {
        self.session = session
        self.promptAssembler = promptAssembler
    }

    public func generate(
        request: GenerationRequest,
        apiKey: String?,
        provider: ProviderSettings
    ) async throws -> [GeneratedCandidate] {
        guard let apiKey, !apiKey.isEmpty else {
            throw AppError.missingAPIKey
        }

        guard let url = URL(string: provider.openAIBaseURL) else {
            throw AppError.generationFailed("The configured API base URL is invalid.")
        }

        let body = try buildRequestBody(for: request, provider: provider)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)

        guard data.count < 5_000_000 else {
            throw AppError.generationFailed("The API returned an unexpectedly large response (\(data.count / 1_000_000) MB).")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError("The server did not return a valid HTTP response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? decoder.decode(APIErrorEnvelope.self, from: data) {
                throw AppError.generationFailed(apiError.error.message)
            }
            throw AppError.networkError("HTTP \(httpResponse.statusCode)")
        }

        let payload = try decoder.decode(ResponseEnvelope.self, from: data)
        let jsonText = payload.output
            .flatMap(\.content)
            .compactMap(\.text)
            .joined(separator: "\n")

        let prompt = promptAssembler.assemble(request: request)
        return try parseCandidates(from: jsonText, expectedCount: prompt.expectedCandidateCount)
    }

    func buildRequestBody(for request: GenerationRequest, provider: ProviderSettings) throws -> Data {
        let prompt = promptAssembler.assemble(request: request)
        let body = ResponsesRequest(
            model: provider.openAIModel,
            input: [
                ResponsesInputMessage(
                    role: "user",
                    content: [
                        ResponsesInputContent(type: "input_text", text: prompt.userMessage)
                    ]
                )
            ],
            instructions: prompt.instructions,
            maxOutputTokens: 650,
            store: false,
            text: ResponsesTextFormat(
                format: ResponseFormat(
                    type: "json_schema",
                    name: "linkedin_comment_candidates",
                    schema: prompt.schema,
                    strict: true
                )
            )
        )

        return try encoder.encode(body)
    }

    func parseCandidates(from jsonText: String, expectedCount: Int = 3) throws -> [GeneratedCandidate] {
        guard !jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.generationFailed("The model returned an empty response.")
        }

        let envelope: GeneratedCandidatesEnvelope
        do {
            let data = Data(jsonText.utf8)
            envelope = try decoder.decode(GeneratedCandidatesEnvelope.self, from: data)
        } catch {
            guard
                let jsonOnlyText = extractJSONObject(from: jsonText),
                let extractedData = jsonOnlyText.data(using: .utf8)
            else {
                throw AppError.generationFailed("The model returned malformed JSON.")
            }

            do {
                envelope = try decoder.decode(GeneratedCandidatesEnvelope.self, from: extractedData)
            } catch {
                throw AppError.generationFailed("The model returned malformed JSON.")
            }
        }

        guard envelope.candidates.count == expectedCount else {
            throw AppError.generationFailed("The model did not return exactly \(expectedCount) comment candidate(s).")
        }

        return envelope.candidates.map {
            GeneratedCandidate(
                id: $0.id,
                text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines),
                lengthCategory: $0.lengthCategory
            )
        }
    }

    private func extractJSONObject(from rawText: String) -> String? {
        guard let startIndex = rawText.firstIndex(of: "{") else {
            return nil
        }

        guard let endIndex = rawText.lastIndex(of: "}") else {
            return nil
        }

        guard startIndex <= endIndex else {
            return nil
        }

        return String(rawText[startIndex...endIndex])
    }
}

@MainActor
public final class ProviderRoutingCommentGeneratorService: CommentGeneratorService {
    private let openAIService: OpenAICommentGeneratorService
    private let ollamaService: OllamaCommentGeneratorService

    public init(
        openAIService: OpenAICommentGeneratorService = OpenAICommentGeneratorService(),
        ollamaService: OllamaCommentGeneratorService = OllamaCommentGeneratorService()
    ) {
        self.openAIService = openAIService
        self.ollamaService = ollamaService
    }

    public func generate(
        request: GenerationRequest,
        apiKey: String?,
        provider: ProviderSettings
    ) async throws -> [GeneratedCandidate] {
        switch provider.kind {
        case .openAI:
            return try await openAIService.generate(request: request, apiKey: apiKey, provider: provider)
        case .ollama:
            return try await ollamaService.generate(request: request, apiKey: nil, provider: provider)
        }
    }
}

private struct ResponsesRequest: Encodable {
    var model: String
    var input: [ResponsesInputMessage]
    var instructions: String
    var maxOutputTokens: Int
    var store: Bool
    var text: ResponsesTextFormat

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case instructions
        case maxOutputTokens = "max_output_tokens"
        case store
        case text
    }
}

private struct ResponsesInputMessage: Encodable {
    var role: String
    var content: [ResponsesInputContent]
}

private struct ResponsesInputContent: Encodable {
    var type: String
    var text: String
}

private struct ResponsesTextFormat: Encodable {
    var format: ResponseFormat
}

private struct ResponseFormat: Encodable {
    var type: String
    var name: String
    var schema: JSONValue
    var strict: Bool
}

private struct ResponseEnvelope: Decodable {
    var output: [ResponseItem]
}

private struct ResponseItem: Decodable {
    var content: [ResponseContent]
}

private struct ResponseContent: Decodable {
    var text: String?
}

private struct APIErrorEnvelope: Decodable {
    struct APIErrorPayload: Decodable {
        var message: String
    }

    var error: APIErrorPayload
}

private struct GeneratedCandidatesEnvelope: Decodable {
    var candidates: [GeneratedCandidatePayload]
}

private struct GeneratedCandidatePayload: Decodable {
    var id: String
    var text: String
    var lengthCategory: CommentLengthCategory
}
