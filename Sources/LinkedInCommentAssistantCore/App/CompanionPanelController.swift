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
        let panelSize = model.overlayPanelSize
        guard let screen = resolvedScreen(near: sourceWindowFrame) else { return }
        let visibleFrame = screen.visibleFrame

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
        if let sourceWindowFrame,
           let matchingScreen = NSScreen.screens.first(where: { $0.frame.intersects(sourceWindowFrame) }) {
            return matchingScreen
        }

        if let mainScreen = NSScreen.main {
            return mainScreen
        }

        return NSScreen.screens.first
    }
}

private final class EdgeOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
