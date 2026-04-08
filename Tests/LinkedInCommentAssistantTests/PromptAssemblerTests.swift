import Testing
@testable import LinkedInCommentAssistantCore

struct PromptAssemblerTests {
    @Test
    func assembleIncludesPersonaIntentLanguageAndCapsExamplesAtFive() {
        let profile = PersonaProfile(
            name: "Operator Voice",
            defaultLanguage: "English",
            defaultIntent: .agree,
            maxCommentSentences: 3,
            voice: "Specific and practical.",
            tone: "Warm and sharp.",
            doRules: ["Reference a concrete idea", "Add one brief take"],
            avoidRules: ["Do not flatter without substance"]
        )

        let examples = (1...6).map { index in
            StyleCorpusEntry(
                text: "Example comment \(index)",
                languageCode: "en",
                fingerprint: "example comment \(index)"
            )
        }

        let request = GenerationRequest(
            postText: "The post is about building better teams.",
            ocrConfidence: 0.82,
            languageSelection: .spanish,
            customLanguage: "",
            intent: .congratulate,
            uniqueThought: "I liked the hiring loop point.",
            personaProfile: profile,
            styleExamples: examples,
            additionalPromptContext: "Avoid sounding generic and keep the tone operator-focused."
        )

        let bundle = PromptAssembler().assemble(request: request)

        #expect(bundle.instructions.contains("Operator Voice"))
        #expect(bundle.instructions.contains("Specific and practical."))
        #expect(bundle.instructions.contains("Write every candidate entirely in the requested language"))
        // Fix 5 replaced the single-line "Honor the requested comment intent"
        // with a dedicated per-intent guidance block.
        #expect(bundle.instructions.contains("Comment intent — Congratulate"))
        #expect(bundle.instructions.contains("congratulate the author on the specific achievement"))
        #expect(bundle.userMessage.contains("Comment intent: Congratulate"))
        #expect(bundle.userMessage.contains("Requested language: Spanish"))
        #expect(bundle.userMessage.contains("I liked the hiring loop point."))
        #expect(bundle.userMessage.contains("Example comment 5"))
        #expect(!bundle.userMessage.contains("Example comment 6"))
        #expect(bundle.expectedCandidateCount == 3)
    }

    @Test
    func assembledSchemaDoesNotIncludeRationale() {
        // Fix 2: rationale must be gone from both properties and required.
        let profile = PersonaProfile(
            name: "Voice",
            defaultLanguage: "English",
            defaultIntent: .agree,
            maxCommentSentences: 3,
            voice: "Clear",
            tone: "Warm",
            doRules: ["Do a thing"],
            avoidRules: ["Avoid another thing"]
        )

        let request = GenerationRequest(
            postText: "A post.",
            ocrConfidence: 0.9,
            languageSelection: .english,
            customLanguage: "",
            intent: .agree,
            uniqueThought: "",
            personaProfile: profile,
            styleExamples: [],
            additionalPromptContext: ""
        )

        let bundle = PromptAssembler().assemble(request: request)

        // Walk the schema JSON tree looking for "rationale" — it must never appear.
        #expect(!jsonContainsKey(bundle.schema, key: "rationale"))
        #expect(!jsonContainsString(bundle.schema, value: "rationale"))
    }

    @Test
    func assembledReworkRequestHasSingleItemSchema() {
        // Fix 3: when reworkTarget is set, expectedCandidateCount == 1 and
        // schema minItems/maxItems are both 1.
        let profile = PersonaProfile(
            name: "Voice",
            defaultLanguage: "English",
            defaultIntent: .agree,
            maxCommentSentences: 3,
            voice: "Clear",
            tone: "Warm",
            doRules: ["Do a thing"],
            avoidRules: ["Avoid another thing"]
        )

        let request = GenerationRequest(
            postText: "A post.",
            ocrConfidence: 0.9,
            languageSelection: .english,
            customLanguage: "",
            intent: .agree,
            uniqueThought: "",
            personaProfile: profile,
            styleExamples: [],
            additionalPromptContext: "",
            reworkTarget: "The original comment text to rework."
        )

        let bundle = PromptAssembler().assemble(request: request)

        #expect(bundle.expectedCandidateCount == 1)
        #expect(bundle.instructions.contains("Return exactly 1 comment."))
        #expect(bundle.instructions.contains("reworking the existing comment"))
        #expect(bundle.userMessage.contains("Original comment to rework:"))
        #expect(bundle.userMessage.contains("The original comment text to rework."))

        // minItems/maxItems in the generated schema should both be 1.
        let schemaString = jsonStringify(bundle.schema)
        #expect(schemaString.contains("\"minItems\":1"))
        #expect(schemaString.contains("\"maxItems\":1"))
    }

    @Test
    func assembledInstructionsIncludeAskQuestionGuidance() {
        let profile = PersonaProfile(
            name: "Voice",
            defaultLanguage: "English",
            defaultIntent: .agree,
            maxCommentSentences: 3,
            voice: "Clear",
            tone: "Warm",
            doRules: ["Do a thing"],
            avoidRules: ["Avoid another thing"]
        )

        let request = GenerationRequest(
            postText: "Post.",
            ocrConfidence: 0.9,
            languageSelection: .english,
            customLanguage: "",
            intent: .askQuestion,
            uniqueThought: "",
            personaProfile: profile,
            styleExamples: [],
            additionalPromptContext: ""
        )

        let bundle = PromptAssembler().assemble(request: request)
        #expect(bundle.instructions.contains("question mark"))
        #expect(bundle.instructions.contains("Comment intent — Ask Question"))
    }

    @Test
    func retryFeedbackInjectedIntoUserMessage() {
        let profile = PersonaProfile(
            name: "Voice",
            defaultLanguage: "English",
            defaultIntent: .agree,
            maxCommentSentences: 3,
            voice: "Clear",
            tone: "Warm",
            doRules: ["Do a thing"],
            avoidRules: ["Avoid another thing"]
        )

        let postText = "The original post about hiring systems."
        let request = GenerationRequest(
            postText: postText,
            ocrConfidence: 0.9,
            languageSelection: .english,
            customLanguage: "",
            intent: .askQuestion,
            uniqueThought: "",
            personaProfile: profile,
            styleExamples: [],
            additionalPromptContext: "",
            retryFeedback: "test feedback about questions"
        )

        let bundle = PromptAssembler().assemble(request: request)

        #expect(bundle.userMessage.contains("test feedback about questions"))
        // Feedback should come AFTER the post text so the model sees it last.
        let postRange = bundle.userMessage.range(of: postText)
        let feedbackRange = bundle.userMessage.range(of: "test feedback about questions")
        #expect(postRange != nil)
        #expect(feedbackRange != nil)
        if let p = postRange, let f = feedbackRange {
            #expect(p.lowerBound < f.lowerBound)
        }
    }
}

// MARK: - Schema inspection helpers (kept at file scope so multiple @Tests can reuse them)

private func jsonContainsKey(_ value: JSONValue, key: String) -> Bool {
    switch value {
    case .object(let dict):
        if dict[key] != nil { return true }
        for (_, v) in dict {
            if jsonContainsKey(v, key: key) { return true }
        }
        return false
    case .array(let items):
        return items.contains(where: { jsonContainsKey($0, key: key) })
    default:
        return false
    }
}

private func jsonContainsString(_ value: JSONValue, value needle: String) -> Bool {
    switch value {
    case .string(let s):
        return s == needle
    case .object(let dict):
        return dict.values.contains(where: { jsonContainsString($0, value: needle) })
    case .array(let items):
        return items.contains(where: { jsonContainsString($0, value: needle) })
    default:
        return false
    }
}

private func jsonStringify(_ value: JSONValue) -> String {
    // Deterministic-ish flattening for substring checks.
    switch value {
    case .string(let s):
        return "\"\(s)\""
    case .number(let n):
        // Emit integers without the trailing ".0" so substring matches work.
        if n.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(n))
        }
        return String(n)
    case .bool(let b):
        return b ? "true" : "false"
    case .null:
        return "null"
    case .array(let items):
        return "[" + items.map(jsonStringify).joined(separator: ",") + "]"
    case .object(let dict):
        let pairs = dict.map { "\"\($0.key)\":\(jsonStringify($0.value))" }
        return "{" + pairs.joined(separator: ",") + "}"
    }
}
