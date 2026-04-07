import LinkedInCommentAssistantCore
import SwiftUI

@main
struct LinkedInCommentAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra("LKD Comments", systemImage: "text.bubble") {
            Button("Scan LinkedIn Feed") {
                model.presentCurrentCompanion()
                model.triggerScan()
            }

            Button(model.isReadingModeActive ? "Exit Reading Mode" : "Enter Reading Mode") {
                model.toggleReadingMode()
            }

            Button(model.isOverlayExpanded ? "Collapse Overlay" : "Show Overlay") {
                if model.isOverlayExpanded {
                    model.dismissCompanion()
                } else {
                    model.toggleOverlayExpanded()
                }
                model.presentCurrentCompanion()
            }

            Divider()

            Button("Open Settings") {
                model.openSettingsWindow()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            SettingsView(model: model)
        }
    }
}
