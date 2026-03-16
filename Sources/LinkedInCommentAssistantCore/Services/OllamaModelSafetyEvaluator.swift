import Foundation

struct OllamaModelDescriptor: Equatable {
    var name: String
    var sizeBytes: Int64?
    var parameterSize: String?
}

enum OllamaModelSafety: Equatable {
    case safe
    case risky(String)
}

struct OllamaModelSafetyEvaluator {
    // Keep local generation conservative. Models above this range were unstable on this machine.
    static let maximumRecommendedParameterCount = 10_000_000_000.0
    static let maximumRecommendedSizeBytes = Int64(8_000_000_000)

    static func evaluate(_ model: OllamaModelDescriptor) -> OllamaModelSafety {
        if let parameterCount = parseParameterCount(model.parameterSize),
           parameterCount > maximumRecommendedParameterCount {
            return .risky(
                "Model \(model.name) is too large for safe local generation here. Use a 7B or 3B Ollama model, or switch to OpenAI."
            )
        }

        if let sizeBytes = model.sizeBytes,
           sizeBytes > maximumRecommendedSizeBytes {
            return .risky(
                "Model \(model.name) is too large for safe local generation here. Use a 7B or 3B Ollama model, or switch to OpenAI."
            )
        }

        return .safe
    }

    static func parseParameterCount(_ value: String?) -> Double? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return nil }

        let suffix = trimmed.last
        let multiplier: Double
        let numericPart: String

        switch suffix {
        case "K":
            multiplier = 1_000
            numericPart = String(trimmed.dropLast())
        case "M":
            multiplier = 1_000_000
            numericPart = String(trimmed.dropLast())
        case "B":
            multiplier = 1_000_000_000
            numericPart = String(trimmed.dropLast())
        case "T":
            multiplier = 1_000_000_000_000
            numericPart = String(trimmed.dropLast())
        default:
            multiplier = 1
            numericPart = trimmed
        }

        guard let baseValue = Double(numericPart) else {
            return nil
        }

        return baseValue * multiplier
    }
}
