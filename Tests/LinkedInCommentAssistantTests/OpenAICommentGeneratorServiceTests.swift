import Testing
@testable import LinkedInCommentAssistantCore

@MainActor
struct OpenAICommentGeneratorServiceTests {
    @Test
    func parseCandidatesRejectsMalformedJSON() {
        let service = OpenAICommentGeneratorService()

        #expect(throws: (any Error).self) {
            try service.parseCandidates(from: "not valid json")
        }
    }

    @Test
    func parseCandidatesReturnsThreeCandidates() throws {
        let payload = """
        {
          "candidates": [
            {
              "id": "one",
              "text": "Really strong point on making the hiring loop explicit.",
              "lengthCategory": "short"
            },
            {
              "id": "two",
              "text": "I like how you tied team resilience to clear feedback loops instead of vague culture talk.",
              "lengthCategory": "medium"
            },
            {
              "id": "three",
              "text": "This makes me think the strongest hiring systems are the ones that make expectations legible to everyone involved.",
              "lengthCategory": "expanded"
            }
          ]
        }
        """

        let candidates = try OpenAICommentGeneratorService().parseCandidates(from: payload)

        #expect(candidates.count == 3)
        #expect(candidates[0].id == "one")
        #expect(candidates[2].lengthCategory == .expanded)
    }

    @Test
    func parseCandidatesHandlesWrappedJSONPayload() throws {
        let payload = """
        ```json
        {
          "candidates": [
            {
              "id": "one",
              "text": "First",
              "lengthCategory": "short"
            },
            {
              "id": "two",
              "text": "Second",
              "lengthCategory": "medium"
            },
            {
              "id": "three",
              "text": "Third",
              "lengthCategory": "expanded"
            }
          ]
        }
        ```
        """

        let candidates = try OpenAICommentGeneratorService().parseCandidates(from: payload)

        #expect(candidates.count == 3)
        #expect(candidates[1].text == "Second")
    }

    @Test
    func parseCandidatesSucceedsWithoutRationaleField() throws {
        // Schema is `strict: true`; rationale must not be required anywhere.
        // This fixture contains only the 3 fields the new schema accepts.
        let payload = """
        {
          "candidates": [
            { "id": "a", "text": "Alpha", "lengthCategory": "short" },
            { "id": "b", "text": "Bravo", "lengthCategory": "medium" },
            { "id": "c", "text": "Charlie", "lengthCategory": "expanded" }
          ]
        }
        """

        let candidates = try OpenAICommentGeneratorService().parseCandidates(from: payload)
        #expect(candidates.count == 3)
        #expect(candidates[0].text == "Alpha")
        #expect(candidates[2].lengthCategory == .expanded)
    }
}
