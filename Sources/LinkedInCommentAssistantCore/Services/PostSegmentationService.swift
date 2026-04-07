import CoreGraphics
import Foundation

public final class PostSegmentationService {
    public init() {}

    public func estimatedFeedRegion(from blocks: [OCRBlock], imageSize: CGSize) -> CGRect {
        let fallback = CGRect(
            x: imageSize.width * 0.18,
            y: imageSize.height * 0.02,
            width: imageSize.width * 0.46,
            height: imageSize.height * 0.92
        )

        let topChromeCutoff = inferredTopChromeCutoff(from: blocks, imageSize: imageSize)
        let bottomCutoff = imageSize.height * 0.985
        let eligibleBlocks = blocks.filter { block in
            let frame = block.frame
            let wordCount = wordCount(in: block.text)
            let withinVerticalBand = frame.maxY > topChromeCutoff && frame.minY < bottomCutoff
            let withinHorizontalBand = frame.midX > imageSize.width * 0.12 && frame.midX < imageSize.width * 0.74
            let meaningful = wordCount >= 2 || frame.width > imageSize.width * 0.08
            return withinVerticalBand && withinHorizontalBand && meaningful
        }

        guard !eligibleBlocks.isEmpty else {
            return fallback
        }

        let weightedCenterX = eligibleBlocks.reduce(into: (sum: Double(0), weight: Double(0))) { partial, block in
            let weight = blockWeight(for: block, imageSize: imageSize)
            partial.sum += Double(block.frame.midX) * weight
            partial.weight += weight
        }

        let preferredCenterX = weightedCenterX.weight > 0
            ? CGFloat(weightedCenterX.sum / weightedCenterX.weight)
            : fallback.midX
        let clampedCenterX = min(max(preferredCenterX, imageSize.width * 0.28), imageSize.width * 0.54)

        let seedBlocks = eligibleBlocks.filter { abs($0.frame.midX - clampedCenterX) < imageSize.width * 0.18 }
        let xMin = max(
            imageSize.width * 0.14,
            (seedBlocks.map(\.frame.minX).min() ?? fallback.minX) - imageSize.width * 0.04
        )
        let xMax = min(
            imageSize.width * 0.72,
            (seedBlocks.map(\.frame.maxX).max() ?? fallback.maxX) + imageSize.width * 0.04
        )

        guard xMax > xMin else {
            return fallback
        }

        return CGRect(x: xMin, y: topChromeCutoff, width: xMax - xMin, height: bottomCutoff - topChromeCutoff)
    }

    public func feedRegionBlocks(from blocks: [OCRBlock], imageSize: CGSize) -> [OCRBlock] {
        feedRegionBlocks(from: blocks, imageSize: imageSize, feedRegion: estimatedFeedRegion(from: blocks, imageSize: imageSize))
    }

    public func feedCandidateBlocks(from blocks: [OCRBlock], imageSize: CGSize) -> [OCRBlock] {
        feedCandidateBlocks(from: blocks, imageSize: imageSize, feedRegion: estimatedFeedRegion(from: blocks, imageSize: imageSize))
    }

    private func feedRegionBlocks(from blocks: [OCRBlock], imageSize: CGSize, feedRegion: CGRect) -> [OCRBlock] {
        blocks.filter { block in
            let frame = block.frame
            let horizontalIntersection = frame.intersection(feedRegion).width
            return horizontalIntersection >= max(frame.width * 0.25, 18) &&
                frame.maxY > feedRegion.minY &&
                frame.minY < feedRegion.maxY
        }
    }

    private func feedCandidateBlocks(from blocks: [OCRBlock], imageSize: CGSize, feedRegion: CGRect) -> [OCRBlock] {
        let topChromeCutoff = inferredTopChromeCutoff(from: blocks, imageSize: imageSize)
        let bottomCutoff = imageSize.height * 0.985

        return blocks.filter { block in
            let frame = block.frame
            let wordCount = wordCount(in: block.text)
            let widthRatio = frame.width / max(imageSize.width, 1)
            let horizontalIntersection = frame.intersection(feedRegion).width
            let centeredEnough = horizontalIntersection >= max(frame.width * 0.25, 18)
            let withinVerticalBand = frame.maxY > topChromeCutoff && frame.minY < bottomCutoff
            let largeEnough = widthRatio > 0.06 || wordCount >= 3 || block.lines.count >= 2
            let looksLikeToolbar = looksLikeTopChrome(block, imageSize: imageSize)
            let looksLikeTinyBadge = frame.width < imageSize.width * 0.05 && wordCount < 3

            return centeredEnough && withinVerticalBand && largeEnough && !looksLikeToolbar && !looksLikeTinyBadge
        }
    }

    public func joinedText(from blocks: [OCRBlock]) -> String {
        blocks
            .map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    public func detectPosts(
        from blocks: [OCRBlock],
        imageSize: CGSize,
        linkedInConfidence: Double,
        classifier: LinkedInContextClassifier
    ) -> PostDetectionResult {
        let feedRegion = estimatedFeedRegion(from: blocks, imageSize: imageSize)
        let candidateBlocks = feedCandidateBlocks(from: blocks, imageSize: imageSize, feedRegion: feedRegion)
        let centralBlocks = {
            let regionBlocks = feedRegionBlocks(from: blocks, imageSize: imageSize, feedRegion: feedRegion)
            return regionBlocks.isEmpty ? candidateBlocks : regionBlocks
        }()
            .sorted { $0.frame.minY < $1.frame.minY }

        guard !centralBlocks.isEmpty else {
            return PostDetectionResult(
                dominantPost: nil,
                alternatePosts: [],
                warnings: ["No usable OCR blocks were found inside the estimated LinkedIn feed column."]
            )
        }

        let clusters = buildClusters(from: centralBlocks)
        let posts = clusters.map { cluster -> DetectedPost in
            let text = cluster.map(\.text).joined(separator: "\n")
            let frame = cluster.reduce(CGRect.null) { $0.union($1.frame) }
            let anchors = classifier.extractAnchors(in: text)
            let wordCount = wordCount(in: text)
            let averageConfidence = cluster.map(\.averageConfidence).reduce(0, +) / Double(cluster.count)

            let centerXScore = 1 - min(abs(frame.midX - feedRegion.midX) / max(feedRegion.width * 0.5, 1), 1)
            let centerYScore = 1 - min(abs(frame.midY - imageSize.height * 0.48) / max(imageSize.height * 0.48, 1), 1)
            let densityScore = min(Double(wordCount) / 90.0, 1.0)
            let areaScore = min(Double(frame.area / max(feedRegion.area * 0.32, 1)), 1.0)
            let anchorScore = min(Double(anchors.count) / 4.0, 1.0)
            let widthScore = min(Double(frame.width / max(feedRegion.width * 0.72, 1)), 1.0)
            let authorCueScore = min(Double(authorCueCount(in: text)) / 3.0, 1.0)
            let topPenalty = frame.minY < feedRegion.minY + imageSize.height * 0.015 ? 0.18 : 0
            let farSidePenalty = frame.minX < feedRegion.minX - imageSize.width * 0.04 || frame.maxX > feedRegion.maxX + imageSize.width * 0.04 ? 0.22 : 0
            let lowWordPenalty = wordCount < 20 ? 0.18 : 0
            let candidateCoverage = coverageRatio(of: cluster, within: candidateBlocks)

            let score = max(
                0,
                min(
                    0.22 * centerYScore +
                    0.15 * centerXScore +
                    0.20 * densityScore +
                    0.14 * areaScore +
                    0.13 * anchorScore +
                    0.08 * widthScore +
                    0.10 * authorCueScore +
                    0.08 * candidateCoverage +
                    0.12 * linkedInConfidence -
                    topPenalty -
                    farSidePenalty -
                    lowWordPenalty,
                    1
                )
            )

            var warnings: [String] = []
            if text.lowercased().contains("see more") {
                warnings.append("The post text appears truncated.")
            }
            if anchors.isEmpty {
                warnings.append("Interaction anchors were weak inside this candidate.")
            }
            if wordCount < 18 {
                warnings.append("The detected post contains limited visible text.")
            }

            return DetectedPost(
                text: text,
                frame: frame,
                score: score,
                averageConfidence: averageConfidence,
                anchors: anchors,
                warnings: warnings
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.frame.area > rhs.frame.area
            }
            return lhs.score > rhs.score
        }

        var warnings: [String] = []
        if let top = posts.first, top.score < 0.40 {
            warnings.append("Post detection confidence is low. Review or crop the extracted text before generating.")
        }
        if posts.count > 1, let first = posts.first, let second = posts.dropFirst().first, abs(first.score - second.score) < 0.08 {
            warnings.append("Multiple visible posts scored similarly. Confirm the extracted text before generating.")
        }

        return PostDetectionResult(
            dominantPost: posts.first,
            alternatePosts: Array(posts.dropFirst().prefix(2)),
            warnings: warnings
        )
    }

    private func buildClusters(from blocks: [OCRBlock]) -> [[OCRBlock]] {
        var clusters: [[OCRBlock]] = []
        var currentCluster: [OCRBlock] = []

        for block in blocks {
            guard let previous = currentCluster.last else {
                currentCluster = [block]
                continue
            }

            let verticalGap = block.frame.minY - previous.frame.maxY
            let horizontalShift = abs(block.frame.minX - previous.frame.minX)
            let shouldAppend = verticalGap < max(previous.frame.height * 1.5, 60) && horizontalShift < max(block.frame.width, previous.frame.width) * 0.7

            if shouldAppend {
                currentCluster.append(block)
            } else {
                clusters.append(currentCluster)
                currentCluster = [block]
            }
        }

        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }

        return clusters
    }

    private func wordCount(in text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    private func blockWeight(for block: OCRBlock, imageSize: CGSize) -> Double {
        let words = max(wordCount(in: block.text), 2)
        let widthFactor = max(Double(block.frame.width / max(imageSize.width * 0.14, 1)), 0.5)
        let centrality = 1 - min(abs(block.frame.midX - imageSize.width * 0.44) / max(imageSize.width * 0.44, 1), 1)
        return Double(words) * min(widthFactor, 2.2) * (0.4 + centrality)
    }

    private func authorCueCount(in text: String) -> Int {
        let lowercased = text.lowercased()
        let cues = ["follow", "edited", "visit my website", "commented on this", "reposted this"]
        var count = cues.filter { lowercased.contains($0) }.count

        if lowercased.range(of: #"(\b\d+[hdw]\b)|(\b\d+\s*(hour|hours|day|days|week|weeks)\b)"#, options: .regularExpression) != nil {
            count += 1
        }

        return count
    }

    private func inferredTopChromeCutoff(from blocks: [OCRBlock], imageSize: CGSize) -> CGFloat {
        let chromeBlocks = blocks.filter { looksLikeTopChrome($0, imageSize: imageSize) }

        if let chromeMaxY = chromeBlocks.map(\.frame.maxY).max() {
            return min(max(chromeMaxY + imageSize.height * 0.008, imageSize.height * 0.01), imageSize.height * 0.12)
        }

        return imageSize.height * 0.01
    }

    private func looksLikeTopChrome(_ block: OCRBlock, imageSize: CGSize) -> Bool {
        let frame = block.frame
        let topArea = frame.minY < imageSize.height * 0.14
        let shortBlock = frame.height < imageSize.height * 0.05
        let wideEnough = frame.width > imageSize.width * 0.16
        let authorish = authorCueCount(in: block.text) > 0
        let lowercased = block.text.lowercased()
        let postish = lowercased.contains("follow") || lowercased.contains("commented on this") || lowercased.contains("reposted this")

        return topArea && shortBlock && wideEnough && !authorish && !postish
    }

    private func coverageRatio(of cluster: [OCRBlock], within candidates: [OCRBlock]) -> Double {
        guard !cluster.isEmpty, !candidates.isEmpty else { return 0 }

        let clusterFrame = cluster.reduce(CGRect.null) { $0.union($1.frame) }
        let matching = candidates.filter { block in
            block.frame.intersection(clusterFrame).area >= max(block.frame.area * 0.35, 24)
        }

        return min(Double(matching.count) / Double(max(cluster.count, 1)), 1)
    }
}
