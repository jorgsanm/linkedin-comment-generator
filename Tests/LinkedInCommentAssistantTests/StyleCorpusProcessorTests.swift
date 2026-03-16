import Testing
@testable import LinkedInCommentAssistantCore

struct StyleCorpusProcessorTests {
    @Test
    func processSplitsNormalizesAndDeduplicatesEntries() {
        let rawText = """
        Great point about shipping faster while keeping quality high.

        Great point about shipping faster while keeping quality high!

        Me gustó mucho cómo conectaste la cultura del equipo con la ejecución.

        Strong takeaway on hiring with real examples instead of abstractions.
        """

        let processor = StyleCorpusProcessor()
        let entries = processor.process(rawText: rawText)

        #expect(entries.count == 3)
        #expect(entries.contains(where: { $0.text.contains("shipping faster") }))
        #expect(entries.contains(where: { $0.text.contains("Me gustó mucho") }))
    }

    @Test
    func selectRelevantExamplesPrefersTokenOverlapAndRespectsLimit() {
        let processor = StyleCorpusProcessor()
        let entries = processor.process(
            rawText: """
            Hiring well gets easier when your scorecards are explicit.

            This is a thoughtful point on hiring loops and interview calibration.

            Product teams move faster when scope is explicit.

            Culture comments with no overlap at all.

            Another hiring comment with operators and hiring managers.

            Sixth example that should be excluded by the limit.
            """
        )

        let selected = processor.selectRelevantExamples(
            from: entries,
            for: "Hiring managers need better interview calibration and explicit scorecards.",
            preferredLanguage: "en",
            limit: 5
        )

        #expect(selected.count == 5)
        #expect(selected.first?.text.lowercased().contains("hiring") == true)
    }
}
