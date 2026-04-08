import AppKit
import SwiftUI

@MainActor
public final class CompanionPanelController: NSObject {
    private var panel: EdgeOverlayPanel?

    public override init() {
        super.init()
    }

    public func present(model: AppModel, near sourceWindowFrame: CGRect?) {
        let panel = panel ?? buildPanel(model: model)
        updateRootView(of: panel, with: model)
        applyLayout(to: panel, model: model, near: sourceWindowFrame, animated: panel.isVisible)
        panel.orderFrontRegardless()
    }

    public func dismiss() {
        panel?.orderOut(nil)
    }

    private func buildPanel(model: AppModel) -> EdgeOverlayPanel {
        let panel = EdgeOverlayPanel(
            contentRect: CGRect(x: 0, y: 0, width: 340, height: 800),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false

        updateRootView(of: panel, with: model)
        self.panel = panel
        return panel
    }

    private func updateRootView(of panel: NSPanel, with model: AppModel) {
        panel.contentView = NSHostingView(rootView: CompanionPanelView(model: model))
    }

    private func applyLayout(to panel: NSPanel, model: AppModel, near sourceWindowFrame: CGRect?, animated: Bool) {
        guard let screen = resolvedScreen(near: sourceWindowFrame) else { return }
        let visibleFrame = screen.visibleFrame

        // Take width from the model; height always comes from the resolved screen
        // so the panel is correctly sized on mixed-height multi-display setups.
        let panelSize = CGSize(width: model.overlayPanelWidth, height: visibleFrame.height)

        let x: CGFloat
        switch model.overlayEdge {
        case .left:
            x = visibleFrame.minX
        case .right:
            x = visibleFrame.maxX - panelSize.width
        }

        let frame = CGRect(origin: CGPoint(x: x, y: visibleFrame.minY), size: panelSize)
        panel.setFrame(frame, display: true, animate: animated)
    }

    private func resolvedScreen(near sourceWindowFrame: CGRect?) -> NSScreen? {
        if let sourceWindowFrame {
            var bestScreen: NSScreen?
            var bestArea: CGFloat = 0
            for candidate in NSScreen.screens {
                let intersection = candidate.frame.intersection(sourceWindowFrame)
                if intersection.isNull { continue }
                let area = intersection.width * intersection.height
                if area > bestArea {
                    bestArea = area
                    bestScreen = candidate
                }
            }
            if let bestScreen { return bestScreen }
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}

private final class EdgeOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
