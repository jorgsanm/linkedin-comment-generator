import Foundation
import NaturalLanguage

public final class StyleCorpusProcessor {
    public init() {}

    public func process(rawText: String) -> [StyleCorpusEntry] {
        let paragraphs = splitParagraphs(from: rawText)
        var seenFingerprints = Set<String>()
        var entries: [StyleCorpusEntry] = []

        for paragraph in paragraphs {
            let normalized = normalizeWhitespace(paragraph)
            guard !normalized.isEmpty else { continue }

            let fingerprint = fingerprint(for: normalized)
            guard !fingerprint.isEmpty, seenFingerprints.insert(fingerprint).inserted else {
                continue
            }

            entries.append(
                StyleCorpusEntry(
                    text: normalized,
                    languageCode: detectLanguage(for: normalized),
                    fingerprint: fingerprint
                )
            )
        }

        return entries
    }

    public func selectRelevantExamples(
        from entries: [StyleCorpusEntry],
        for postText: String,
        preferredLanguage: String?,
        limit: Int = 5
    ) -> [StyleCorpusEntry] {
        let postTokens = Set(tokenize(postText))
        let normalizedPreferredLanguage = preferredLanguage?.lowercased()

        let scoredEntries = entries.map { entry -> (StyleCorpusEntry, Double) in
            let entryTokens = Set(tokenize(entry.text))
            let overlap = Double(postTokens.intersection(entryTokens).count)
            let union = Double(postTokens.union(entryTokens).count)
            let jaccard = union == 0 ? 0 : overlap / union
            let lengthScore = min(Double(entry.text.count) / 220.0, 1.0) * 0.2
            let languageBoost = normalizedPreferredLanguage != nil && entry.languageCode?.lowercased() == normalizedPreferredLanguage ? 0.15 : 0
            return (entry, jaccard + lengthScore + languageBoost)
        }

        return scoredEntries
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.text.count > rhs.0.text.count
                }
                return lhs.1 > rhs.1
            }
            .prefix(limit)
            .map(\.0)
    }

    func fingerprint(for text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func splitParagraphs(from rawText: String) -> [String] {
        var paragraphs: [String] = []
        var current: [String] = []

        for rawLine in rawText.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !current.isEmpty {
                    paragraphs.append(current.joined(separator: " "))
                    current.removeAll(keepingCapacity: true)
                }
            } else {
                current.append(line)
            }
        }

        if !current.isEmpty {
            paragraphs.append(current.joined(separator: " "))
        }

        return paragraphs
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func detectLanguage(for text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    private func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
    }
}
