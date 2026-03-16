import Testing
@testable import LinkedInCommentAssistantCore

struct APIKeyFileParserTests {
    @Test
    func parsesEnvStyleAPIKey() throws {
        let contents = """
        OPENAI_API_KEY=sk-test-12345678901234567890
        """

        let apiKey = try APIKeyFileParser().parse(contents: contents)

        #expect(apiKey == "sk-test-12345678901234567890")
    }

    @Test
    func parsesRawAPIKeyValue() throws {
        let apiKey = try APIKeyFileParser().parse(contents: "\"sk-test-abcdefghijklmnopqrstuvwxyz\"")

        #expect(apiKey == "sk-test-abcdefghijklmnopqrstuvwxyz")
    }

    @Test
    func throwsForMissingAPIKey() {
        #expect(throws: (any Error).self) {
            try APIKeyFileParser().parse(contents: "# no key here")
        }
    }
}
