import AppKit
import SwiftUI

public struct CropSelectionView: View {
    private let image: CGImage
    private let onConfirm: (CGImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var dragStartPoint: CGPoint?
    @State private var selectionRect: CGRect = .zero
    @State private var displayedImageRect: CGRect = .zero

    public init(image: CGImage, onConfirm: @escaping (CGImage) -> Void) {
        self.image = image
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Manual Crop")
                .font(.title2.weight(.semibold))

            GeometryReader { proxy in
                let availableRect = CGRect(origin: .zero, size: proxy.size)
                let imageRect = aspectFitRect(for: CGSize(width: image.width, height: image.height), in: availableRect)

                ZStack {
                    Color.black.opacity(0.9)

                    Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageRect.width, height: imageRect.height)
                        .position(x: imageRect.midX, y: imageRect.midY)

                    Rectangle()
                        .path(in: imageRect)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)

                    if !selectionRect.isEmpty {
                        Rectangle()
                            .stroke(Color(red: 0.29, green: 0.75, blue: 0.42), lineWidth: 2)
                            .background(
                                Rectangle()
                                    .fill(Color(red: 0.29, green: 0.75, blue: 0.42).opacity(0.18))
                            )
                            .frame(width: selectionRect.width, height: selectionRect.height)
                            .position(x: selectionRect.midX, y: selectionRect.midY)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .onAppear {
                    displayedImageRect = imageRect
                }
                .onChange(of: proxy.size) { _, _ in
                    displayedImageRect = imageRect
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            displayedImageRect = imageRect
                            let currentPoint = clamp(value.location, to: imageRect)
                            if dragStartPoint == nil {
                                dragStartPoint = clamp(value.startLocation, to: imageRect)
                            }
                            selectionRect = normalizedRect(from: dragStartPoint ?? currentPoint, to: currentPoint)
                        }
                        .onEnded { _ in
                            dragStartPoint = nil
                        }
                )
            }
            .frame(minHeight: 480)

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Crop") {
                    guard let cropped = cropSelection() else { return }
                    onConfirm(cropped)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectionRect.width < 30 || selectionRect.height < 30)
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 620)
        .background(Color(red: 0.08, green: 0.10, blue: 0.08))
    }

    private func cropSelection() -> CGImage? {
        guard selectionRect.width > 0, selectionRect.height > 0, displayedImageRect.width > 0, displayedImageRect.height > 0 else {
            return nil
        }
        let imageSize = CGSize(width: image.width, height: image.height)

        let normalizedX = (selectionRect.minX - displayedImageRect.minX) / displayedImageRect.width
        let normalizedY = (selectionRect.minY - displayedImageRect.minY) / displayedImageRect.height
        let normalizedWidth = selectionRect.width / displayedImageRect.width
        let normalizedHeight = selectionRect.height / displayedImageRect.height

        let pixelRect = CGRect(
            x: normalizedX * imageSize.width,
            y: normalizedY * imageSize.height,
            width: normalizedWidth * imageSize.width,
            height: normalizedHeight * imageSize.height
        )
        .integral
        .intersection(CGRect(origin: .zero, size: imageSize))

        return image.cropping(to: pixelRect)
    }

    private func aspectFitRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let aspectWidth = bounds.width / imageSize.width
        let aspectHeight = bounds.height / imageSize.height
        let scale = min(aspectWidth, aspectHeight)
        let width = imageSize.width * scale
        let height = imageSize.height * scale

        return CGRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func clamp(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}
