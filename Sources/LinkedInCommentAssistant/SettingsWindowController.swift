import AppKit
import LinkedInCommentAssistantCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(model: AppModel) {
        let window = window ?? buildWindow(model: model)
        updateRootView(of: window, model: model)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow(model: AppModel) -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 920, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LinkedIn Assistant Settings"
        window.titleVisibility = .visible
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("LinkedInAssistantSettingsWindow")
        window.delegate = self
        updateRootView(of: window, model: model)
        self.window = window
        return window
    }

    private func updateRootView(of window: NSWindow, model: AppModel) {
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
    }
}
