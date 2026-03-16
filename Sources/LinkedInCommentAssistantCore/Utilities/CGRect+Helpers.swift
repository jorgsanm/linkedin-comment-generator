import CoreGraphics

extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }

    func intersectionRatio(with other: CGRect) -> CGFloat {
        let overlap = intersection(other)
        let minArea = min(area, other.area)
        guard minArea > 0 else { return 0 }
        return overlap.area / minArea
    }

    func clamped(to bounds: CGRect) -> CGRect {
        intersection(bounds)
    }
}

extension CGSize {
    var cgRect: CGRect { CGRect(origin: .zero, size: self) }
}
