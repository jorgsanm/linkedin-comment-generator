import Foundation

public final class PersonaProfileParser {
    public init() {}

    public func parse(url: URL) throws -> PersonaProfile {
        let contents = try String(contentsOf: url, encoding: .utf8)
        var profile = try parse(contents: contents)
        profile.sourcePath = url.path
        return profile
    }

    public func parse(contents: String) throws -> PersonaProfile {
        let normalized = contents.replacingOccurrences(of: "\r\n", with: "\n")
        let (frontMatter, body) = try extractFrontMatter(from: normalized)
        let metadata = try parseFrontMatter(frontMatter)
        let sections = parseSections(body)

        guard let name = metadata["name"], !name.isEmpty else {
            throw AppError.invalidPersonaFile("Missing required front matter key `name`.")
        }

        let defaultLanguage = metadata["default_language"] ?? "English"

        guard
            let defaultIntentRaw = metadata["default_intent"],
            let defaultIntent = CommentIntent(slug: defaultIntentRaw)
        else {
            throw AppError.invalidPersonaFile("`default_intent` must be one of agree, disagree, ask question, or congratulate.")
        }

        guard
            let maxSentencesRaw = metadata["max_comment_sentences"],
            let maxSentences = Int(maxSentencesRaw),
            maxSentences > 0
        else {
            throw AppError.invalidPersonaFile("`max_comment_sentences` must be a positive integer.")
        }

        guard let voice = sections["Voice"], !voice.isEmpty else {
            throw AppError.invalidPersonaFile("Missing required `## Voice` section.")
        }

        guard let tone = sections["Tone"], !tone.isEmpty else {
            throw AppError.invalidPersonaFile("Missing required `## Tone` section.")
        }

        let doRules = parseList(from: sections["Do"])
        guard !doRules.isEmpty else {
            throw AppError.invalidPersonaFile("Missing required `## Do` section or bullet list.")
        }

        let avoidRules = parseList(from: sections["Avoid"])
        guard !avoidRules.isEmpty else {
            throw AppError.invalidPersonaFile("Missing required `## Avoid` section or bullet list.")
        }

        return PersonaProfile(
            name: name,
            defaultLanguage: defaultLanguage,
            defaultIntent: defaultIntent,
            maxCommentSentences: maxSentences,
            voice: voice,
            tone: tone,
            doRules: doRules,
            avoidRules: avoidRules,
            audience: sections["Audience"],
            ctaRules: parseList(from: sections["CTA Rules"]),
            bannedPhrases: parseList(from: sections["Banned Phrases"])
        )
    }

    private func extractFrontMatter(from text: String) throws -> (String, String) {
        guard text.hasPrefix("---\n") else {
            throw AppError.invalidPersonaFile("The persona file must start with YAML front matter enclosed by `---`.")
        }

        let components = text.components(separatedBy: "\n---\n")
        guard components.count >= 2 else {
            throw AppError.invalidPersonaFile("The persona file front matter is not closed correctly.")
        }

        let frontMatter = components[0].replacingOccurrences(of: "---\n", with: "")
        let body = components.dropFirst().joined(separator: "\n---\n")
        return (frontMatter, body)
    }

    private func parseFrontMatter(_ frontMatter: String) throws -> [String: String] {
        var parsed: [String: String] = [:]

        for rawLine in frontMatter.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            guard let separatorIndex = line.firstIndex(of: ":") else {
                throw AppError.invalidPersonaFile("Invalid front matter line: \(line)")
            }

            let key = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            parsed[key] = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }

        return parsed
    }

    private func parseSections(_ markdown: String) -> [String: String] {
        var sections: [String: [String]] = [:]
        var currentHeading: String?

        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)

            if line.hasPrefix("## ") {
                currentHeading = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                if sections[currentHeading ?? ""] == nil {
                    sections[currentHeading ?? ""] = []
                }
            } else if let currentHeading {
                sections[currentHeading, default: []].append(line)
            }
        }

        return sections.mapValues { lines in
            lines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func parseList(from rawSection: String?) -> [String] {
        guard let rawSection else { return [] }

        let bulletLikeLines = rawSection
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { line in
                String(line)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "^-\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "^\\*\\s*", with: "", options: .regularExpression)
            }
            .filter { !$0.isEmpty }

        if !bulletLikeLines.isEmpty {
            return bulletLikeLines
        }

        return rawSection
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
