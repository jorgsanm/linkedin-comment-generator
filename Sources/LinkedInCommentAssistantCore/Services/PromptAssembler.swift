import Foundation

struct PromptBundle {
    var instructions: String
    var userMessage: String
    var schema: JSONValue
}

public final class PromptAssembler {
    public init() {}

    func assemble(request: GenerationRequest) -> PromptBundle {
        let profile = request.personaProfile
        let cappedExamples = Array(request.styleExamples.prefix(5))

        let instructions = """
        You generate assistive LinkedIn comments based only on the visible OCR text from a post.
        Follow the provided persona exactly.

        Persona name: \(profile.name)
        Voice:
        \(profile.voice)

        Tone:
        \(profile.tone)

        Do:
        \(profile.doRules.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        Avoid:
        \(profile.avoidRules.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        CTA rules:
        \(profile.ctaRules.isEmpty ? "None" : profile.ctaRules.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        Banned phrases:
        \(profile.bannedPhrases.isEmpty ? "None" : profile.bannedPhrases.joined(separator: ", "))

        Audience:
        \(profile.audience?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? profile.audience! : "Not specified")

        Constraints:
        - Return exactly 3 distinct comments.
        - Each comment must fit within \(profile.maxCommentSentences) sentence(s).
        - Keep the tone human and natural.
        - Honor the requested comment intent exactly.
        - Write every candidate entirely in the requested language. Do not mix languages unless the request explicitly asks for it.
        - Treat the persona, extra context, and style examples as consistent instructions, not optional suggestions.
        - Do not claim to have read anything beyond the visible post text.
        - Do not add hashtags unless the post clearly demands them.
        """

        let examplesText: String
        if cappedExamples.isEmpty {
            examplesText = "None provided."
        } else {
            examplesText = cappedExamples.enumerated()
                .map { index, entry in
                    "Example \(index + 1): \(entry.text)"
                }
                .joined(separator: "\n")
        }

        let userMessage = """
        Visible post text:
        \(request.postText)

        OCR confidence: \(String(format: "%.2f", request.ocrConfidence))
        Comment intent: \(request.intent.displayName)
        Requested language: \(request.resolvedLanguageLabel)
        Unique thought to weave in: \(request.uniqueThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None" : request.uniqueThought)
        Extra context and prompt notes:
        \(request.additionalPromptContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None provided." : request.additionalPromptContext)
        Style examples:
        \(examplesText)
        """

        return PromptBundle(
            instructions: instructions,
            userMessage: userMessage,
            schema: JSONValue.object(
                [
                    "type": .string("object"),
                    "additionalProperties": .bool(false),
                    "properties": .object(
                        [
                            "candidates": .object(
                                [
                                    "type": .string("array"),
                                    "minItems": .number(3),
                                    "maxItems": .number(3),
                                    "items": .object(
                                        [
                                            "type": .string("object"),
                                            "additionalProperties": .bool(false),
                                            "properties": .object(
                                                [
                                                    "id": .object(["type": .string("string")]),
                                                    "text": .object(["type": .string("string")]),
                                                    "rationale": .object(["type": .string("string")]),
                                                    "lengthCategory": .object(
                                                        [
                                                            "type": .string("string"),
                                                            "enum": .array([
                                                                .string(CommentLengthCategory.short.rawValue),
                                                                .string(CommentLengthCategory.medium.rawValue),
                                                                .string(CommentLengthCategory.expanded.rawValue)
                                                            ])
                                                        ]
                                                    )
                                                ]
                                            ),
                                            "required": .array([
                                                .string("id"),
                                                .string("text"),
                                                .string("rationale"),
                                                .string("lengthCategory")
                                            ])
                                        ]
                                    )
                                ]
                            )
                        ]
                    ),
                    "required": .array([.string("candidates")])
                ]
            )
        )
    }
}
