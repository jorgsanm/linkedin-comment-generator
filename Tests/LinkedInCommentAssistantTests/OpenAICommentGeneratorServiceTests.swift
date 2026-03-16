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
              "rationale": "Specific agreement with one concrete takeaway.",
              "lengthCategory": "short"
            },
            {
              "id": "two",
              "text": "I like how you tied team resilience to clear feedback loops instead of vague culture talk.",
              "rationale": "Highlights a precise detail from the post.",
              "lengthCategory": "medium"
            },
            {
              "id": "three",
              "text": "This makes me think the strongest hiring systems are the ones that make expectations legible to everyone involved.",
              "rationale": "Adds a brief reflection without drifting away from the post.",
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
              "rationale": "A",
              "lengthCategory": "short"
            },
            {
              "id": "two",
              "text": "Second",
              "rationale": "B",
              "lengthCategory": "medium"
            },
            {
              "id": "three",
              "text": "Third",
              "rationale": "C",
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
}
