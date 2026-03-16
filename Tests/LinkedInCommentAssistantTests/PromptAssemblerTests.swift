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
        #expect(bundle.instructions.contains("Honor the requested comment intent exactly"))
        #expect(bundle.userMessage.contains("Comment intent: Congratulate"))
        #expect(bundle.userMessage.contains("Requested language: Spanish"))
        #expect(bundle.userMessage.contains("I liked the hiring loop point."))
        #expect(bundle.userMessage.contains("Example comment 5"))
        #expect(!bundle.userMessage.contains("Example comment 6"))
    }
}
