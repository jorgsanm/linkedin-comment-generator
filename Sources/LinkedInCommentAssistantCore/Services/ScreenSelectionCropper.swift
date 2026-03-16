import CoreGraphics
import Foundation

public final class ScreenSelectionCropper {
    public init() {}

    public func pixelCropRect(
        for selectionFrame: CGRect,
        inContainerFrame containerFrame: CGRect,
        imageSize: CGSize
    ) -> CGRect? {
        guard containerFrame.width > 0, containerFrame.height > 0 else {
            return nil
        }

        let clampedSelection = selectionFrame.intersection(containerFrame)
        guard !clampedSelection.isNull, !clampedSelection.isEmpty else {
            return nil
        }

        let normalizedX = (clampedSelection.minX - containerFrame.minX) / containerFrame.width
        let normalizedY = (containerFrame.maxY - clampedSelection.maxY) / containerFrame.height
        let normalizedWidth = clampedSelection.width / containerFrame.width
        let normalizedHeight = clampedSelection.height / containerFrame.height

        return CGRect(
            x: normalizedX * imageSize.width,
            y: normalizedY * imageSize.height,
            width: normalizedWidth * imageSize.width,
            height: normalizedHeight * imageSize.height
        )
        .integral
        .intersection(CGRect(origin: .zero, size: imageSize))
    }

    public func pixelCropRect(
        for selectionFrame: CGRect,
        inWindowFrame windowFrame: CGRect,
        imageSize: CGSize
    ) -> CGRect? {
        pixelCropRect(for: selectionFrame, inContainerFrame: windowFrame, imageSize: imageSize)
    }

    public func crop(
        image: CGImage,
        selectionFrame: CGRect,
        inWindowFrame windowFrame: CGRect
    ) -> CGImage? {
        guard let cropRect = pixelCropRect(
            for: selectionFrame,
            inContainerFrame: windowFrame,
            imageSize: CGSize(width: image.width, height: image.height)
        ),
        !cropRect.isEmpty
        else {
            return nil
        }

        return image.cropping(to: cropRect)
    }
}
