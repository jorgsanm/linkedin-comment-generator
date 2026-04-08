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
        let jsonTemplate: String
        if prompt.expectedCandidateCount == 1 {
            jsonTemplate = """
            {
              "candidates": [
                {
                  "id": "1",
                  "text": "your comment here",
                  "lengthCategory": "medium"
                }
              ]
            }
            """
        } else {
            jsonTemplate = """
            {
              "candidates": [
                {
                  "id": "1",
                  "text": "your comment here",
                  "lengthCategory": "short"
                },
                {
                  "id": "2",
                  "text": "your comment here",
                  "lengthCategory": "medium"
                },
                {
                  "id": "3",
                  "text": "your comment here",
                  "lengthCategory": "expanded"
                }
              ]
            }
            """
        }
        let fullPrompt = """
        \(prompt.instructions)

        You MUST return ONLY a JSON object matching this exact structure (no other text):
        \(jsonTemplate)

        lengthCategory must be one of: "short", "medium", "expanded"

        \(prompt.userMessage)
        """

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60
        urlRequest.httpBody = try encoder.encode(
            OllamaGenerateRequest(
                model: provider.ollamaModel,
                system: "You are a precise LinkedIn comment generator. You MUST return valid JSON only. No markdown, no explanation, just the JSON object.",
                prompt: fullPrompt,
                stream: false,
                format: .string("json"),
                options: OllamaGenerateOptions(
                    temperature: 0.45,
                    numPredict: 800,
                    numCtx: 2048,
                    repeatPenalty: 1.05
                )
            )
        )

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard data.count < 5_000_000 else {
                throw AppError.generationFailed("Ollama returned an unexpectedly large response (\(data.count / 1_000_000) MB).")
            }

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
            let responseText = envelope.response.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !responseText.isEmpty else {
                throw AppError.generationFailed(
                    "Ollama returned an empty response. The model \(provider.ollamaModel) may not support JSON output. Try a different model like llama3.1:8b or qwen2.5:7b."
                )
            }

            return try responseParser.parseCandidates(from: responseText)
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw AppError.generationFailed(
                    "Ollama took too long to respond. The model may be loading into memory. Try again in a moment."
                )
            }
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
