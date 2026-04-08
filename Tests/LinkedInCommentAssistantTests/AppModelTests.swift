import Testing
@testable import LinkedInCommentAssistantCore

@MainActor
struct AppModelTests {
    // MARK: - Fix 5: Ask Question validator

    @Test
    func askQuestionValidatorFlagsTrailingTagQuestions() {
        let model = AppModel(commentGenerator: StubGenerator(batches: []))
        let candidates = [
            GeneratedCandidate(id: "1", text: "Great point?", lengthCategory: .short), // 2 words
            GeneratedCandidate(id: "2", text: "Nice work?", lengthCategory: .short),   // 2 words
            GeneratedCandidate(id: "3", text: "What about the follow-up plan?", lengthCategory: .medium) // valid
        ]

        let feedback = model.validateCandidates(candidates, intent: .askQuestion)
        #expect(feedback != nil)
        #expect(feedback!.contains("not real questions"))
    }

    @Test
    func askQuestionValidatorAcceptsProperQuestions() {
        let model = AppModel(commentGenerator: StubGenerator(batches: []))
        let candidates = [
            GeneratedCandidate(id: "1", text: "What was the hardest part of shipping this?", lengthCategory: .medium),
            GeneratedCandidate(id: "2", text: "How did you measure success here?", lengthCategory: .short),
            GeneratedCandidate(id: "3", text: "Which metric surprised you most?", lengthCategory: .short)
        ]

        let feedback = model.validateCandidates(candidates, intent: .askQuestion)
        #expect(feedback == nil)
    }

    @Test
    func validatorReturnsNilForNonAskQuestionIntents() {
        let model = AppModel(commentGenerator: StubGenerator(batches: []))
        // Statements would fail the question rule, but the intent is .agree
        // so the validator should short-circuit to nil.
        let candidates = [
            GeneratedCandidate(id: "1", text: "Completely agree.", lengthCategory: .short),
            GeneratedCandidate(id: "2", text: "This is spot on.", lengthCategory: .short),
            GeneratedCandidate(id: "3", text: "Great analysis.", lengthCategory: .short)
        ]

        for intent in [CommentIntent.agree, .disagree, .congratulate, .free] {
            #expect(model.validateCandidates(candidates, intent: intent) == nil)
        }
    }

    // MARK: - Fix 5: Retry loop via stub service

    @Test
    func askQuestionRetryLoopFiresExactlyOnce() async throws {
        // Stub returns invalid statements first, then valid questions on retry.
        let invalid = [
            GeneratedCandidate(id: "a", text: "This is a statement.", lengthCategory: .short),
            GeneratedCandidate(id: "b", text: "Another statement.", lengthCategory: .short),
            GeneratedCandidate(id: "c", text: "One more statement.", lengthCategory: .short)
        ]
        let valid = [
            GeneratedCandidate(id: "1", text: "What was the hardest part?", lengthCategory: .short),
            GeneratedCandidate(id: "2", text: "How did you measure success?", lengthCategory: .short),
            GeneratedCandidate(id: "3", text: "Which metric surprised you?", lengthCategory: .short)
        ]

        let stub = StubGenerator(batches: [invalid, valid])
        let model = AppModel(commentGenerator: stub)

        let request = makeRequest(intent: .askQuestion)
        let result = try await model.performGenerationWithRetry(
            request: request,
            apiKey: "test",
            provider: ProviderSettings()
        )

        #expect(stub.callCount == 2)
        #expect(result.didRetry == true)
        #expect(result.candidates.count == 3)
        #expect(result.candidates[0].text == "What was the hardest part?")

        // The second call MUST have retryFeedback set and mention questions.
        let secondRequest = stub.receivedRequests[1]
        #expect(secondRequest.retryFeedback != nil)
        #expect(secondRequest.retryFeedback!.contains("question"))
    }

    @Test
    func askQuestionRetryLoopGivesUpAfterOneRetry() async throws {
        // Stub returns invalid statements on BOTH calls.
        let invalid = [
            GeneratedCandidate(id: "a", text: "A statement.", lengthCategory: .short),
            GeneratedCandidate(id: "b", text: "Another statement.", lengthCategory: .short),
            GeneratedCandidate(id: "c", text: "Third statement.", lengthCategory: .short)
        ]
        let stub = StubGenerator(batches: [invalid, invalid])
        let model = AppModel(commentGenerator: stub)

        let request = makeRequest(intent: .askQuestion)
        let result = try await model.performGenerationWithRetry(
            request: request,
            apiKey: "test",
            provider: ProviderSettings()
        )

        #expect(stub.callCount == 2)
        #expect(result.didRetry == true)
        #expect(result.candidates == invalid) // the second (still-invalid) batch
    }

    @Test
    func askQuestionSuccessOnFirstTryDoesNotRetry() async throws {
        let valid = [
            GeneratedCandidate(id: "1", text: "What did you learn here?", lengthCategory: .short),
            GeneratedCandidate(id: "2", text: "How will you scale this?", lengthCategory: .short),
            GeneratedCandidate(id: "3", text: "Which team led this work?", lengthCategory: .short)
        ]
        let stub = StubGenerator(batches: [valid])
        let model = AppModel(commentGenerator: stub)

        let request = makeRequest(intent: .askQuestion)
        let result = try await model.performGenerationWithRetry(
            request: request,
            apiKey: "test",
            provider: ProviderSettings()
        )

        #expect(stub.callCount == 1)
        #expect(result.didRetry == false)
        #expect(result.candidates == valid)
    }

    @Test
    func lastGenerationDidRetryFlagReflectsRetry() {
        let model = AppModel(commentGenerator: StubGenerator(batches: []))
        #expect(model.lastGenerationDidRetry == false)

        model.applyRetryMetadata(didRetry: true)
        #expect(model.lastGenerationDidRetry == true)

        model.applyRetryMetadata(didRetry: false)
        #expect(model.lastGenerationDidRetry == false)
    }

    // MARK: - Fix 6: Copy does not collapse

    @Test
    func copyCandidateDoesNotCollapseOverlay() {
        let model = AppModel(commentGenerator: StubGenerator(batches: []))
        let candidate = GeneratedCandidate(id: "1", text: "Hello there.", lengthCategory: .short)

        // Overlay starts expanded by default; assert so the test's premise is explicit.
        #expect(model.isOverlayExpanded == true)

        model.copy(candidate: candidate)

        #expect(model.isOverlayExpanded == true)
        #expect(model.statusMessage == "Copied candidate to clipboard.")
    }

    // MARK: - Helpers

    private func makeRequest(intent: CommentIntent) -> GenerationRequest {
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

        return GenerationRequest(
            postText: "A representative post.",
            ocrConfidence: 0.9,
            languageSelection: .english,
            customLanguage: "",
            intent: intent,
            uniqueThought: "",
            personaProfile: profile,
            styleExamples: [],
            additionalPromptContext: ""
        )
    }
}

// MARK: - Stub comment generator

@MainActor
private final class StubGenerator: CommentGeneratorService {
    var batches: [[GeneratedCandidate]]
    var callCount = 0
    var receivedRequests: [GenerationRequest] = []

    init(batches: [[GeneratedCandidate]]) {
        self.batches = batches
    }

    func generate(
        request: GenerationRequest,
        apiKey: String?,
        provider: ProviderSettings
    ) async throws -> [GeneratedCandidate] {
        receivedRequests.append(request)
        defer { callCount += 1 }

        if callCount < batches.count {
            return batches[callCount]
        }
        throw AppError.generationFailed("stub ran out of batches")
    }
}
