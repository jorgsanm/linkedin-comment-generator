import CoreGraphics
import Testing
@testable import LinkedInCommentAssistantCore

struct PostSegmentationServiceTests {
    @Test
    func detectPostsPrefersDominantCentralFeedPost() {
        let centralText = "Alice Smith\nLoved this point about building resilient teams through explicit hiring loops and clear feedback."
        let interactionText = "Like Comment Repost Send"
        let leftRailText = "Home My Network Jobs Messaging"
        let rightRailText = "Follow Trending in tech"

        let blocks = [
            OCRBlock(lines: [], text: leftRailText, frame: CGRect(x: 40, y: 140, width: 220, height: 140), averageConfidence: 0.95),
            OCRBlock(lines: [], text: centralText, frame: CGRect(x: 360, y: 280, width: 760, height: 180), averageConfidence: 0.94),
            OCRBlock(lines: [], text: interactionText, frame: CGRect(x: 380, y: 480, width: 700, height: 54), averageConfidence: 0.92),
            OCRBlock(lines: [], text: rightRailText, frame: CGRect(x: 1180, y: 180, width: 210, height: 120), averageConfidence: 0.90)
        ]

        let classifier = LinkedInContextClassifier()
        let classification = classifier.classify(blocks: blocks, imageSize: CGSize(width: 1440, height: 1800))
        let result = PostSegmentationService().detectPosts(
            from: blocks,
            imageSize: CGSize(width: 1440, height: 1800),
            linkedInConfidence: classification.confidence,
            classifier: classifier
        )

        #expect(result.dominantPost != nil)
        #expect(result.dominantPost?.text.contains("resilient teams") == true)
        #expect((result.dominantPost?.score ?? 0) > 0.40)
    }

    @Test
    func feedCandidateBlocksExcludeToolbarAndBookmarkText() {
        let service = PostSegmentationService()
        let blocks = [
            OCRBlock(lines: [], text: "Docs Design Tools Finance", frame: CGRect(x: 420, y: 100, width: 420, height: 28), averageConfidence: 0.96),
            OCRBlock(lines: [], text: "A thoughtful post about hiring loops, calibration, and making expectations explicit across the team.", frame: CGRect(x: 360, y: 320, width: 760, height: 170), averageConfidence: 0.95)
        ]

        let filtered = service.feedCandidateBlocks(from: blocks, imageSize: CGSize(width: 1440, height: 1800))

        #expect(filtered.count == 1)
        #expect(filtered.first?.text.contains("hiring loops") == true)
    }

    @Test
    func feedCandidateBlocksKeepPostWhenOcrSplitsTextIntoShortLines() {
        let service = PostSegmentationService()
        let blocks = [
            OCRBlock(lines: [], text: "Pivot Webinar Product Hunt", frame: CGRect(x: 250, y: 92, width: 480, height: 26), averageConfidence: 0.96),
            OCRBlock(lines: [], text: "Jorge Sanchez", frame: CGRect(x: 90, y: 160, width: 180, height: 32), averageConfidence: 0.94),
            OCRBlock(lines: [], text: "Stanislav Beliaev", frame: CGRect(x: 470, y: 220, width: 220, height: 32), averageConfidence: 0.95),
            OCRBlock(lines: [], text: "Co-Founder & CTO", frame: CGRect(x: 470, y: 258, width: 210, height: 28), averageConfidence: 0.95),
            OCRBlock(lines: [], text: "Just found the most useful repo", frame: CGRect(x: 450, y: 318, width: 320, height: 30), averageConfidence: 0.96),
            OCRBlock(lines: [], text: "for Claude Code", frame: CGRect(x: 450, y: 354, width: 180, height: 28), averageConfidence: 0.95),
            OCRBlock(lines: [], text: "It’s a constantly updated", frame: CGRect(x: 450, y: 410, width: 260, height: 28), averageConfidence: 0.95),
            OCRBlock(lines: [], text: "collection of best practices", frame: CGRect(x: 450, y: 446, width: 290, height: 28), averageConfidence: 0.95),
            OCRBlock(lines: [], text: "Add to your feed", frame: CGRect(x: 1010, y: 300, width: 180, height: 28), averageConfidence: 0.94),
            OCRBlock(lines: [], text: "Microsoft Follow", frame: CGRect(x: 1030, y: 360, width: 170, height: 28), averageConfidence: 0.93)
        ]

        let filtered = service.feedCandidateBlocks(from: blocks, imageSize: CGSize(width: 1440, height: 1800))
        let extracted = service.joinedText(from: filtered)

        #expect(!filtered.isEmpty)
        #expect(extracted.contains("Stanislav Beliaev"))
        #expect(extracted.contains("best practices"))
        #expect(!extracted.contains("Microsoft Follow"))
    }
}
