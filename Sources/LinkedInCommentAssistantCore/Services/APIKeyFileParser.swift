import Foundation

public final class APIKeyFileParser {
    public init() {}

    public func parse(url: URL) throws -> String {
        let startedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if startedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let contents = try String(contentsOf: url, encoding: .utf8)
        return try parse(contents: contents)
    }

    public func parse(contents: String) throws -> String {
        let normalized = contents.replacingOccurrences(of: "\r\n", with: "\n")

        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if let separatorIndex = line.firstIndex(of: "=") {
                let key = line[..<separatorIndex]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let value = line[line.index(after: separatorIndex)...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if ["openai_api_key", "api_key"].contains(key) {
                    return try normalizeCandidate(String(value))
                }
            }
        }

        return try normalizeCandidate(normalized.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func normalizeCandidate(_ rawValue: String) throws -> String {
        let trimmed = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        guard !trimmed.isEmpty else {
            throw AppError.invalidAPIKeyFile("No API key value was found.")
        }

        guard trimmed.count >= 20 else {
            throw AppError.invalidAPIKeyFile("The extracted API key looks too short.")
        }

        return trimmed
    }
}
