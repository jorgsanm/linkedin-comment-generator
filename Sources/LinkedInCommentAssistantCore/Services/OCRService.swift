import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Vision

public final class OCRService {
    private let context = CIContext(options: nil)

    public init() {}

    public func recognizeText(in image: CGImage) throws -> OCRResult {
        let processedImage = preprocess(image)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: processedImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let lines = observations.compactMap { observation -> OCRLine? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let boundingBox = observation.boundingBox
            let imageWidth = CGFloat(processedImage.width)
            let imageHeight = CGFloat(processedImage.height)
            let frame = CGRect(
                x: boundingBox.minX * imageWidth,
                y: (1 - boundingBox.maxY) * imageHeight,
                width: boundingBox.width * imageWidth,
                height: boundingBox.height * imageHeight
            )

            return OCRLine(
                text: candidate.string.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: Double(candidate.confidence),
                frame: frame
            )
        }
        .filter { !$0.text.isEmpty }
        .sorted { lhs, rhs in
            if abs(lhs.frame.minY - rhs.frame.minY) < 8 {
                return lhs.frame.minX < rhs.frame.minX
            }
            return lhs.frame.minY < rhs.frame.minY
        }

        let blocks = group(lines: lines)
        let averageConfidence = lines.isEmpty ? 0 : lines.map(\.confidence).reduce(0, +) / Double(lines.count)
        let concatenatedText = blocks.map(\.text).joined(separator: "\n\n")

        return OCRResult(
            processedImage: processedImage,
            lines: lines,
            blocks: blocks,
            averageConfidence: averageConfidence,
            concatenatedText: concatenatedText
        )
    }

    private func preprocess(_ image: CGImage) -> CGImage {
        var ciImage = CIImage(cgImage: image)

        let targetMinWidth: CGFloat = 1400
        let targetMaxDimension: CGFloat = 4000
        let longestSide = max(CGFloat(image.width), CGFloat(image.height))
        let imageWidth = CGFloat(image.width)

        let scale: Float?
        if longestSide > targetMaxDimension {
            scale = Float(targetMaxDimension / longestSide)
        } else if imageWidth < targetMinWidth {
            scale = Float(targetMinWidth / max(imageWidth, 1))
        } else {
            scale = nil
        }

        if let scale {
            let scaleFilter = CIFilter.lanczosScaleTransform()
            scaleFilter.inputImage = ciImage
            scaleFilter.scale = scale
            scaleFilter.aspectRatio = 1
            ciImage = scaleFilter.outputImage ?? ciImage
        }

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.saturation = 0
        colorControls.contrast = 1.15
        colorControls.brightness = 0.02

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = colorControls.outputImage ?? ciImage
        sharpen.sharpness = 0.35

        guard let outputImage = sharpen.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent)
        else {
            return image
        }

        return cgImage
    }

    private func group(lines: [OCRLine]) -> [OCRBlock] {
        guard !lines.isEmpty else { return [] }

        var blocks: [OCRBlock] = []
        var currentLines: [OCRLine] = []
        var currentFrame = CGRect.null

        func flushCurrentBlock() {
            guard !currentLines.isEmpty else { return }
            let text = currentLines.map(\.text).joined(separator: "\n")
            let averageConfidence = currentLines.map(\.confidence).reduce(0, +) / Double(currentLines.count)
            blocks.append(
                OCRBlock(
                    lines: currentLines,
                    text: text,
                    frame: currentFrame,
                    averageConfidence: averageConfidence
                )
            )
            currentLines.removeAll(keepingCapacity: true)
            currentFrame = .null
        }

        for line in lines {
            guard let lastLine = currentLines.last else {
                currentLines = [line]
                currentFrame = line.frame
                continue
            }

            let verticalGap = line.frame.minY - lastLine.frame.maxY
            let horizontalOverlap = lastLine.frame.intersectionRatio(with: line.frame)
            let sameColumn = abs(line.frame.minX - lastLine.frame.minX) < max(line.frame.width, lastLine.frame.width) * 0.5
            let shouldMerge = verticalGap < max(lastLine.frame.height * 1.25, 26) && (horizontalOverlap > 0.1 || sameColumn)

            if shouldMerge {
                currentLines.append(line)
                currentFrame = currentFrame.union(line.frame)
            } else {
                flushCurrentBlock()
                currentLines = [line]
                currentFrame = line.frame
            }
        }

        flushCurrentBlock()
        return blocks
    }
}
