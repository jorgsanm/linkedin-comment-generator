import Testing
@testable import LinkedInCommentAssistantCore

struct PersonaProfileParserTests {
    @Test
    func parsesValidPersonaProfile() throws {
        let markdown = """
        ---
        name: Founder Voice
        default_language: English
        default_intent: agree
        max_comment_sentences: 2
        ---
        ## Voice
        Direct operator voice with concrete observations.

        ## Tone
        Warm, precise, and useful.

        ## Do
        - Mention a specific idea from the post
        - Add a brief personal angle

        ## Avoid
        - Generic praise
        - Buzzwords

        ## Audience
        Founders and operators.

        ## CTA Rules
        - Ask one grounded follow-up question

        ## Banned Phrases
        - game changer
        """

        let profile = try PersonaProfileParser().parse(contents: markdown)

        #expect(profile.name == "Founder Voice")
        #expect(profile.defaultLanguage == "English")
        #expect(profile.defaultIntent == .agree)
        #expect(profile.maxCommentSentences == 2)
        #expect(profile.doRules.count == 2)
        #expect(profile.avoidRules.count == 2)
        #expect(profile.bannedPhrases == ["game changer"])
        #expect(profile.audience == "Founders and operators.")
    }

    @Test
    func missingRequiredSectionThrows() {
        let markdown = """
        ---
        name: Founder Voice
        default_language: English
        default_intent: agree
        max_comment_sentences: 2
        ---
        ## Voice
        Clear operator voice.

        ## Do
        - Be specific

        ## Avoid
        - Empty praise
        """

        #expect(throws: (any Error).self) {
            try PersonaProfileParser().parse(contents: markdown)
        }
    }
}
