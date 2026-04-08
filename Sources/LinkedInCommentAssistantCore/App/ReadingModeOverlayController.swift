import AppKit
import Combine
import SwiftUI

@MainActor
public final class ReadingModeOverlayController: NSObject {
    private enum Layout {
        static let minimumSelectionSize = CGSize(width: 260, height: 180)
        static let screenPadding: CGFloat = 14
        static let toolbarSize = CGSize(width: 380, height: 44)
        static let moveHandleSize = CGSize(width: 152, height: 34)
        static let resizeHandleSize: CGFloat = 18
        static let controlSpacing: CGFloat = 12
    }

    private weak var model: AppModel?
    private var guidePanel: ReadingModeGuidePanel?
    private var guideView: ReadingSelectionGuideView?
    private var toolbarPanel: ReadingModeControlPanel?
    private var moveHandlePanel: ReadingModeControlPanel?
    private var resizeHandlePanels: [ResizeCorner: ReadingModeControlPanel] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private var activeScreen: NSScreen?

    public override init() {
        super.init()
    }

    public func present(model: AppModel, near sourceWindowFrame: CGRect?) {
        self.model = model
        bind(to: model)

        guard let screen = resolvedScreen(near: model.readingSelectionFrame ?? sourceWindowFrame) else { return }
        activeScreen = screen
        ensurePanels(for: screen, model: model)

        let selection = clampedSelection(
            model.readingSelectionFrame ?? defaultSelection(on: screen, suggestedFrame: sourceWindowFrame),
            on: screen
        )
        if model.readingSelectionFrame != selection {
            model.updateReadingSelection(selection)
        } else {
            refreshPanels(for: selection, on: screen, model: model)
        }
    }

    public func dismiss() {
        guidePanel?.orderOut(nil)
        toolbarPanel?.orderOut(nil)
        moveHandlePanel?.orderOut(nil)
        resizeHandlePanels.values.forEach { $0.orderOut(nil) }
        subscriptions.removeAll()
        model = nil
    }

    private func bind(to model: AppModel) {
        subscriptions.removeAll()

        model.$readingSelectionFrame
            .receive(on: RunLoop.main)
            .sink { [weak self, weak model] selection in
                guard let self, let model, let selection,
                      let screen = self.resolvedScreen(near: selection) else { return }
                self.activeScreen = screen
                self.ensurePanels(for: screen, model: model)
                self.refreshPanels(for: self.clampedSelection(selection, on: screen), on: screen, model: model)
            }
            .store(in: &subscriptions)
    }

    private func ensurePanels(for screen: NSScreen, model: AppModel) {
        let guidePanel = guidePanel ?? buildGuidePanel(screen: screen)
        let toolbarPanel = toolbarPanel ?? buildToolbarPanel(model: model)
        let moveHandlePanel = moveHandlePanel ?? buildMoveHandlePanel()

        if guideView == nil {
            let guideView = ReadingSelectionGuideView(frame: CGRect(origin: .zero, size: screen.frame.size))
            guideView.screenFrame = screen.frame
            guidePanel.contentView = guideView
            self.guideView = guideView
        }

        guidePanel.setFrame(screen.frame, display: true)
        guideView?.frame = CGRect(origin: .zero, size: screen.frame.size)
        guideView?.screenFrame = screen.frame

        guidePanel.orderFrontRegardless()
        toolbarPanel.orderFrontRegardless()
        moveHandlePanel.orderFrontRegardless()

        for corner in ResizeCorner.allCases {
            let panel = resizeHandlePanels[corner] ?? buildResizeHandlePanel(for: corner)
            resizeHandlePanels[corner] = panel
            panel.orderFrontRegardless()
        }
    }

    private func refreshPanels(for selection: CGRect, on screen: NSScreen, model: AppModel) {
        guideView?.screenFrame = screen.frame
        guideView?.selectionFrame = selection
        guideView?.needsDisplay = true

        if let toolbarPanel {
            toolbarPanel.setFrame(toolbarFrame(for: selection, on: screen), display: true)
            toolbarPanel.orderFrontRegardless()
        }

        if let moveHandlePanel {
            moveHandlePanel.setFrame(moveHandleFrame(for: selection, on: screen), display: true)
            moveHandlePanel.orderFrontRegardless()
        }

        for corner in ResizeCorner.allCases {
            guard let panel = resizeHandlePanels[corner] else { continue }
            panel.setFrame(resizeHandleFrame(for: corner, selection: selection), display: true)
            panel.orderFrontRegardless()
        }
    }

    private func buildGuidePanel(screen: NSScreen) -> ReadingModeGuidePanel {
        let panel = ReadingModeGuidePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level.statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        guidePanel = panel
        return panel
    }

    private func buildToolbarPanel(model: AppModel) -> ReadingModeControlPanel {
        let panel = ReadingModeControlPanel(
            contentRect: CGRect(origin: .zero, size: Layout.toolbarSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level.statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(
            rootView: ReadingModeToolbarView(
                model: model,
                onScan: { [weak model] in
                    model?.triggerScan()
                },
                onGenerate: { [weak model] in
                    model?.triggerGenerate()
                },
                onScanAndGenerate: { [weak model] in
                    model?.triggerScanAndGenerate()
                },
                onCenterBox: { [weak self] in
                    self?.centerSelection()
                },
                onExit: { [weak model] in
                    model?.exitReadingMode()
                }
            )
        )
        toolbarPanel = panel
        return panel
    }

    private func buildMoveHandlePanel() -> ReadingModeControlPanel {
        let panel = ReadingModeControlPanel(
            contentRect: CGRect(origin: .zero, size: Layout.moveHandleSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level.statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = ReadingSelectionHandleView(style: .move) { [weak self] delta in
            self?.moveSelection(by: delta)
        }
        moveHandlePanel = panel
        return panel
    }

    private func buildResizeHandlePanel(for corner: ResizeCorner) -> ReadingModeControlPanel {
        let panel = ReadingModeControlPanel(
            contentRect: CGRect(origin: .zero, size: CGSize(width: Layout.resizeHandleSize, height: Layout.resizeHandleSize)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level.statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = ReadingSelectionHandleView(style: .resize(corner)) { [weak self] delta in
            self?.resizeSelection(at: corner, by: delta)
        }
        resizeHandlePanels[corner] = panel
        return panel
    }

    private func moveSelection(by delta: CGSize) {
        guard let model, let screen = activeScreen else { return }
        let current = model.readingSelectionFrame ?? defaultSelection(on: screen, suggestedFrame: nil)
        model.updateReadingSelection(
            clampedSelection(current.offsetBy(dx: delta.width, dy: delta.height), on: screen)
        )
    }

    private func centerSelection() {
        guard let model, let screen = activeScreen else { return }
        let current = model.readingSelectionFrame ?? defaultSelection(on: screen, suggestedFrame: nil)
        let bounds = constrainedBounds(for: screen)
        let centered = CGRect(
            x: bounds.midX - current.width / 2,
            y: bounds.midY - current.height / 2,
            width: current.width,
            height: current.height
        )
        model.updateReadingSelection(clampedSelection(centered, on: screen))
    }

    private func resizeSelection(at corner: ResizeCorner, by delta: CGSize) {
        guard let model, let screen = activeScreen else { return }
        let current = model.readingSelectionFrame ?? defaultSelection(on: screen, suggestedFrame: nil)
        model.updateReadingSelection(resizedSelection(current, corner: corner, delta: delta, screen: screen))
    }

    private func resizedSelection(_ selection: CGRect, corner: ResizeCorner, delta: CGSize, screen: NSScreen) -> CGRect {
        let minimumWidth = Layout.minimumSelectionSize.width
        let minimumHeight = Layout.minimumSelectionSize.height

        let left = selection.minX
        let right = selection.maxX
        let bottom = selection.minY
        let top = selection.maxY

        let resized: CGRect
        switch corner {
        case .topLeft:
            let nextLeft = min(left + delta.width, right - minimumWidth)
            let nextTop = max(top + delta.height, bottom + minimumHeight)
            resized = CGRect(x: nextLeft, y: bottom, width: right - nextLeft, height: nextTop - bottom)
        case .topRight:
            let nextRight = max(right + delta.width, left + minimumWidth)
            let nextTop = max(top + delta.height, bottom + minimumHeight)
            resized = CGRect(x: left, y: bottom, width: nextRight - left, height: nextTop - bottom)
        case .bottomLeft:
            let nextLeft = min(left + delta.width, right - minimumWidth)
            let nextBottom = min(bottom + delta.height, top - minimumHeight)
            resized = CGRect(x: nextLeft, y: nextBottom, width: right - nextLeft, height: top - nextBottom)
        case .bottomRight:
            let nextRight = max(right + delta.width, left + minimumWidth)
            let nextBottom = min(bottom + delta.height, top - minimumHeight)
            resized = CGRect(x: left, y: nextBottom, width: nextRight - left, height: top - nextBottom)
        }

        return clampedSelection(resized, on: screen)
    }

    private func toolbarFrame(for selection: CGRect, on screen: NSScreen) -> CGRect {
        // Anchor the toolbar to the reading selection's top-right corner, just
        // above the box — tracking it the same way the Move Box handle does.
        // Fallbacks:
        //   1. If there's no vertical room above the box, flip below it.
        //   2. If either axis still fails to fit, clamp to visible bounds
        //      (this degrades gracefully into "top-left of screen" for a box
        //      pressed against the top-right corner of the display).
        let bounds = constrainedBounds(for: screen)
        let size = Layout.toolbarSize

        var origin = CGPoint(
            x: selection.maxX - size.width,
            y: selection.maxY + Layout.controlSpacing
        )

        if origin.y + size.height > bounds.maxY {
            origin.y = selection.minY - Layout.controlSpacing - size.height
        }

        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
        return CGRect(origin: origin, size: size).integral
    }

    private func moveHandleFrame(for selection: CGRect, on screen: NSScreen) -> CGRect {
        // Prefer placing the Move Box handle BELOW the selection so it stays
        // clear of the (now box-anchored) toolbar sitting above the box.
        // Falls back to above the selection if there is no room below.
        let bounds = constrainedBounds(for: screen)
        var origin = CGPoint(
            x: selection.midX - Layout.moveHandleSize.width / 2,
            y: selection.minY - Layout.moveHandleSize.height - Layout.controlSpacing
        )

        if origin.y < bounds.minY {
            origin.y = selection.maxY + Layout.controlSpacing
        }

        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - Layout.moveHandleSize.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - Layout.moveHandleSize.height)
        return CGRect(origin: origin, size: Layout.moveHandleSize).integral
    }

    private func resizeHandleFrame(for corner: ResizeCorner, selection: CGRect) -> CGRect {
        let center: CGPoint
        switch corner {
        case .topLeft:
            center = CGPoint(x: selection.minX, y: selection.maxY)
        case .topRight:
            center = CGPoint(x: selection.maxX, y: selection.maxY)
        case .bottomLeft:
            center = CGPoint(x: selection.minX, y: selection.minY)
        case .bottomRight:
            center = CGPoint(x: selection.maxX, y: selection.minY)
        }

        return CGRect(
            x: center.x - Layout.resizeHandleSize / 2,
            y: center.y - Layout.resizeHandleSize / 2,
            width: Layout.resizeHandleSize,
            height: Layout.resizeHandleSize
        )
        .integral
    }

    private func clampedSelection(_ selection: CGRect, on screen: NSScreen) -> CGRect {
        let bounds = constrainedBounds(for: screen)
        var clamped = selection.standardized
        clamped.size.width = min(max(clamped.width, Layout.minimumSelectionSize.width), bounds.width)
        clamped.size.height = min(max(clamped.height, Layout.minimumSelectionSize.height), bounds.height)
        clamped.origin.x = min(max(clamped.minX, bounds.minX), bounds.maxX - clamped.width)
        clamped.origin.y = min(max(clamped.minY, bounds.minY), bounds.maxY - clamped.height)
        return clamped.integral
    }

    private func constrainedBounds(for screen: NSScreen) -> CGRect {
        screen.visibleFrame.insetBy(dx: Layout.screenPadding, dy: Layout.screenPadding)
    }

    private func defaultSelection(on screen: NSScreen, suggestedFrame: CGRect?) -> CGRect {
        let bounds = constrainedBounds(for: screen)

        if let suggestedFrame {
            let suggested = suggestedFrame.intersection(bounds)
            if suggested.width >= Layout.minimumSelectionSize.width,
               suggested.height >= Layout.minimumSelectionSize.height {
                return clampedSelection(suggested, on: screen)
            }
        }

        let width = min(max(bounds.width * 0.38, Layout.minimumSelectionSize.width), 760)
        let height = min(max(bounds.height * 0.56, Layout.minimumSelectionSize.height), 940)
        return CGRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )
        .integral
    }

    private func resolvedScreen(near referenceFrame: CGRect?) -> NSScreen? {
        if let referenceFrame,
           let matchingScreen = NSScreen.screens.max(
               by: { $0.frame.intersection(referenceFrame).area < $1.frame.intersection(referenceFrame).area }
           ),
           matchingScreen.frame.intersects(referenceFrame) {
            return matchingScreen
        }

        if let mainScreen = NSScreen.main {
            return mainScreen
        }

        return NSScreen.screens.first
    }
}

private enum ResizeCorner: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var cursor: NSCursor {
        switch self {
        case .topLeft, .bottomRight:
            return .crosshair
        case .topRight, .bottomLeft:
            return .crosshair
        }
    }
}

private final class ReadingModeGuidePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class ReadingModeControlPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class ReadingSelectionGuideView: NSView {
    var screenFrame: CGRect = .zero
    var selectionFrame: CGRect = .zero

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !selectionFrame.isEmpty else { return }

        let localSelection = CGRect(
            x: selectionFrame.minX - screenFrame.minX,
            y: selectionFrame.minY - screenFrame.minY,
            width: selectionFrame.width,
            height: selectionFrame.height
        )

        let glowPath = NSBezierPath(roundedRect: localSelection.insetBy(dx: -3, dy: -3), xRadius: 20, yRadius: 20)
        NSColor(calibratedRed: 0.23, green: 0.56, blue: 1.0, alpha: 0.12).setFill()
        glowPath.fill()

        let borderPath = NSBezierPath(roundedRect: localSelection, xRadius: 18, yRadius: 18)
        borderPath.lineWidth = 2
        NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.98, alpha: 0.98).setStroke()
        borderPath.stroke()

        let innerPath = NSBezierPath(roundedRect: localSelection.insetBy(dx: 4, dy: 4), xRadius: 14, yRadius: 14)
        innerPath.setLineDash([8, 6], count: 2, phase: 0)
        innerPath.lineWidth = 1
        NSColor.white.withAlphaComponent(0.7).setStroke()
        innerPath.stroke()
    }
}

private final class ReadingSelectionHandleView: NSView {
    enum Style {
        case move
        case resize(ResizeCorner)
    }

    private let style: Style
    private let onDelta: (CGSize) -> Void
    private var lastScreenLocation: CGPoint?
    private var trackingArea: NSTrackingArea?

    init(style: Style, onDelta: @escaping (CGSize) -> Void) {
        self.style = style
        self.onDelta = onDelta
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        switch style {
        case .move:
            NSCursor.openHand.push()
        case .resize(let corner):
            corner.cursor.push()
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        lastScreenLocation = screenLocation(for: event)
        switch style {
        case .move:
            NSCursor.closedHand.push()
        case .resize(let corner):
            corner.cursor.push()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let previous = lastScreenLocation else {
            lastScreenLocation = screenLocation(for: event)
            return
        }

        let current = screenLocation(for: event)
        lastScreenLocation = current
        onDelta(CGSize(width: current.x - previous.x, height: current.y - previous.y))
    }

    override func mouseUp(with event: NSEvent) {
        lastScreenLocation = nil
        NSCursor.pop()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        switch style {
        case .move:
            let rect = bounds.insetBy(dx: 1, dy: 1)
            let path = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
            NSColor(calibratedWhite: 0.1, alpha: 0.76).setFill()
            path.fill()
            NSColor.white.withAlphaComponent(0.18).setStroke()
            path.lineWidth = 1
            path.stroke()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraph
            ]
            let text = "Move Box"
            text.draw(
                in: rect.insetBy(dx: 10, dy: 8),
                withAttributes: attributes
            )
        case .resize:
            let circleRect = bounds.insetBy(dx: 1, dy: 1)
            let path = NSBezierPath(ovalIn: circleRect)
            NSColor.white.setFill()
            path.fill()
            NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.98, alpha: 1).setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }

    private func screenLocation(for event: NSEvent) -> CGPoint {
        guard let window else { return .zero }
        return window.convertPoint(toScreen: event.locationInWindow)
    }
}

private struct ReadingModeToolbarView: View {
    private let toolbarSize = CGSize(width: 380, height: 44)

    @ObservedObject var model: AppModel
    let onScan: () -> Void
    let onGenerate: () -> Void
    let onScanAndGenerate: () -> Void
    let onCenterBox: () -> Void
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onCenterBox) {
                Label("Center", systemImage: "scope")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: onScan) {
                Label("Scan", systemImage: "viewfinder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(model.isScanning)

            Button(action: onScanAndGenerate) {
                Label("Scan + Set", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(model.isScanning || model.isGenerating)

            Button(action: onGenerate) {
                Label("New Set", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!model.canGenerate || model.isScanning)

            Button(action: onExit) {
                Label("Exit", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(width: toolbarSize.width, height: toolbarSize.height, alignment: .center)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 6)
    }
}
