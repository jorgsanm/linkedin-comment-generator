import Foundation

@MainActor
public final class OllamaCommentGeneratorService: CommentGeneratorService {
    private let session: URLSession
    private let promptAssembler: PromptAssembler
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let responseParser = OpenAICommentGeneratorService()

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
        guard let url = URL(string: provider.ollamaBaseURL) else {
            throw AppError.generationFailed("The configured Ollama URL is invalid.")
        }

        let prompt = promptAssembler.assemble(request: request)
        let fullPrompt = """
        \(prompt.instructions)

        Return only JSON that matches the requested schema.

        \(prompt.userMessage)
        """

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 45
        urlRequest.httpBody = try encoder.encode(
            OllamaGenerateRequest(
                model: provider.ollamaModel,
                system: "You are a precise LinkedIn comment generator. Return valid JSON only.",
                prompt: fullPrompt,
                stream: false,
                format: prompt.schema,
                options: OllamaGenerateOptions(
                    temperature: 0.45,
                    numPredict: 220,
                    numCtx: 2048,
                    repeatPenalty: 1.05
                )
            )
        )

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkError("The Ollama server did not return a valid HTTP response.")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let apiError = try? decoder.decode(OllamaErrorEnvelope.self, from: data) {
                    throw AppError.generationFailed(apiError.error)
                }
                throw AppError.networkError("Ollama returned HTTP \(httpResponse.statusCode)")
            }

            let envelope = try decoder.decode(OllamaGenerateResponse.self, from: data)
            return try responseParser.parseCandidates(from: envelope.response)
        } catch is URLError {
            throw AppError.missingLocalProvider(
                "The local Ollama server is unavailable at \(provider.ollamaBaseURL). Install/start Ollama and pull \(provider.ollamaModel)."
            )
        } catch {
            throw error
        }
    }
}

private struct OllamaGenerateRequest: Encodable {
    var model: String
    var system: String
    var prompt: String
    var stream: Bool
    var format: JSONValue
    var options: OllamaGenerateOptions
}

private struct OllamaGenerateOptions: Encodable {
    var temperature: Double
    var numPredict: Int
    var numCtx: Int
    var repeatPenalty: Double

    enum CodingKeys: String, CodingKey {
        case temperature
        case numPredict = "num_predict"
        case numCtx = "num_ctx"
        case repeatPenalty = "repeat_penalty"
    }
}

private struct OllamaGenerateResponse: Decodable {
    var response: String
}

private struct OllamaErrorEnvelope: Decodable {
    var error: String
}
