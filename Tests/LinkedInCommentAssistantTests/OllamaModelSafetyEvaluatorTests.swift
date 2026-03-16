import Testing
@testable import LinkedInCommentAssistantCore

struct OllamaModelSafetyEvaluatorTests {
    @Test
    func parseParameterCountUnderstandsBillionSuffix() {
        let parsed = OllamaModelSafetyEvaluator.parseParameterCount("14.8B")
        #expect(parsed == 14_800_000_000)
    }

    @Test
    func evaluateMarksOversizedModelAsRisky() {
        let model = OllamaModelDescriptor(
            name: "qwen2.5:14b",
            sizeBytes: 8_988_124_069,
            parameterSize: "14.8B"
        )

        let result = OllamaModelSafetyEvaluator.evaluate(model)

        switch result {
        case .safe:
            #expect(Bool(false), "Expected oversized model to be marked risky")
        case .risky(let message):
            #expect(message.contains("too large"))
        }
    }

    @Test
    func evaluateAllowsSmallerModel() {
        let model = OllamaModelDescriptor(
            name: "qwen2.5:3b",
            sizeBytes: 2_100_000_000,
            parameterSize: "3.1B"
        )

        let result = OllamaModelSafetyEvaluator.evaluate(model)
        #expect(result == .safe)
    }
}
