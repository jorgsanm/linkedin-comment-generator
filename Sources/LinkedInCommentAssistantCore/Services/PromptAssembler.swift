import Foundation

struct PromptBundle {
    var instructions: String
    var userMessage: String
    var schema: JSONValue
    /// How many candidates callers should expect back from the model. 3 for a
    /// normal generate, 1 for a single-candidate rework.
    var expectedCandidateCount: Int
}

public final class PromptAssembler {
    public init() {}

    func assemble(request: GenerationRequest) -> PromptBundle {
        let profile = request.personaProfile
        let cappedExamples = Array(request.styleExamples.prefix(5))
        let hasCustomContext = !request.additionalPromptContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isBuiltInPersona = profile.name == "Built-In Persona"
        let isRework = request.reworkTarget != nil
        let expectedCount = isRework ? 1 : 3

        var instructionParts: [String] = [
            "You generate assistive LinkedIn comments based only on the visible OCR text from a post."
        ]

        if hasCustomContext {
            instructionParts.append("""
            The user has provided custom guidelines below (in the "Extra context" section). \
            These are the primary instructions for tone, voice, and content. Follow them closely.
            """)
        }

        if !isBuiltInPersona || !hasCustomContext {
            instructionParts.append("""
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
            """)
        }

        let countConstraint: String
        if isRework {
            countConstraint = "- Return exactly 1 comment."
        } else {
            countConstraint = "- Return exactly 3 distinct comments."
        }

        instructionParts.append("""
        Constraints:
        \(countConstraint)
        - Each comment must fit within \(profile.maxCommentSentences) sentence(s).
        - Keep the tone human and natural.
        - Write every candidate entirely in the requested language. Do not mix languages unless the request explicitly asks for it.
        - Treat the persona, extra context, and style examples as consistent instructions, not optional suggestions.
        - Do not claim to have read anything beyond the visible post text.
        - Do not add hashtags unless the post clearly demands them.
        """)

        if isRework {
            instructionParts.append("""
            You are reworking the existing comment below. Keep the same spirit, voice, and tone. \
            Produce ONE new variation that tries a slightly different angle but does not contradict \
            the original. Do not change the language.
            """)
        }

        // Per-intent guidance block (Fix 5). Appended last so it has the highest
        // recency weight in the instruction string.
        instructionParts.append("""
        Comment intent — \(request.intent.displayName):
        \(request.intent.promptGuidance)
        """)

        let instructions = instructionParts.joined(separator: "\n\n")

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

        let intentLine: String
        switch request.intent {
        case .free:
            intentLine = "Comment intent: Not specified — choose the most fitting stance based on the post."
        default:
            intentLine = "Comment intent: \(request.intent.displayName)"
        }

        var userMessage = """
        Visible post text:
        \(request.postText)

        OCR confidence: \(String(format: "%.2f", request.ocrConfidence))
        \(intentLine)
        Requested language: \(request.resolvedLanguageLabel)
        Unique thought to weave in: \(request.uniqueThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None" : request.uniqueThought)
        Extra context and prompt notes:
        \(request.additionalPromptContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None provided." : request.additionalPromptContext)
        Style examples:
        \(examplesText)
        """

        if let reworkTarget = request.reworkTarget {
            userMessage += "\n\nOriginal comment to rework: «\(reworkTarget)»"
        }

        if let feedback = request.retryFeedback,
           !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userMessage += "\n\nIMPORTANT — previous attempt failed: \(feedback) Fix this in the next attempt."
        }

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
                                    "minItems": .number(Double(expectedCount)),
                                    "maxItems": .number(Double(expectedCount)),
                                    "items": .object(
                                        [
                                            "type": .string("object"),
                                            "additionalProperties": .bool(false),
                                            "properties": .object(
                                                [
                                                    "id": .object(["type": .string("string")]),
                                                    "text": .object(["type": .string("string")]),
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
            ),
            expectedCandidateCount: expectedCount
        )
    }
}
