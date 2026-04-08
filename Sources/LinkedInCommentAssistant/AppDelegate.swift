import AppKit
import LinkedInCommentAssistantCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panelController = CompanionPanelController()
    private let readingModeOverlayController = ReadingModeOverlayController()
    private let settingsWindowController = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Hide the default empty SwiftUI placeholder window that .regular activation
        // policy creates. Skip NSPanel instances so we don't accidentally hide our
        // own overlay panels (CompanionPanelController, ReadingModeOverlayController).
        DispatchQueue.main.async {
            for window in NSApp.windows where !(window is NSPanel) && window.title.isEmpty {
                window.orderOut(nil)
            }
        }

        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        }

        let model = AppModel.shared
        model.onPresentCompanion = { [weak self] frame in
            self?.panelController.present(model: model, near: frame)
        }
        model.onDismissCompanion = { [weak self] in
            self?.panelController.dismiss()
        }
        model.onPresentReadingMode = { [weak self] frame in
            self?.readingModeOverlayController.present(model: model, near: frame)
        }
        model.onDismissReadingMode = { [weak self] in
            self?.readingModeOverlayController.dismiss()
        }
        model.onOpenSettingsWindow = { [weak self] in
            self?.settingsWindowController.show(model: model)
        }
        model.start()
        model.presentCurrentCompanion()
    }
}
