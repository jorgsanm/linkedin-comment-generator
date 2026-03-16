import CoreGraphics
import Foundation

public final class LinkedInContextClassifier {
    private let anchors = [
        "like", "comment", "repost", "send", "follow", "see more", "promoted",
        "connections", "impressions", "reactions", "post", "linkedin", "hours", "days"
    ]

    public init() {}

    public func classify(blocks: [OCRBlock], imageSize: CGSize) -> LinkedInClassification {
        let combinedText = blocks.map(\.text).joined(separator: "\n").lowercased()
        let foundAnchors = extractAnchors(in: combinedText)
        let centralBlocks = blocks.filter {
            let frame = $0.frame
            return frame.midX > imageSize.width * 0.18 && frame.midX < imageSize.width * 0.82
        }

        let centralTextWords = centralBlocks
            .flatMap { $0.text.components(separatedBy: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count

        let anchorScore = min(Double(foundAnchors.count) / 6.0, 1.0) * 0.55
        let densityScore = min(Double(centralTextWords) / 120.0, 1.0) * 0.35
        let keywordBoost = combinedText.contains("comment") && combinedText.contains("like") ? 0.1 : 0
        let confidence = min(anchorScore + densityScore + keywordBoost, 1.0)

        var warnings: [String] = []
        if confidence < 0.35 {
            warnings.append("The captured window does not strongly resemble a standard LinkedIn feed.")
        }
        if foundAnchors.isEmpty {
            warnings.append("LinkedIn interaction labels were not found in the OCR output.")
        }

        return LinkedInClassification(confidence: confidence, anchors: foundAnchors, warnings: warnings)
    }

    public func extractAnchors(in text: String) -> [String] {
        let lowercased = text.lowercased()
        return anchors.filter { lowercased.contains($0) }
    }
}
