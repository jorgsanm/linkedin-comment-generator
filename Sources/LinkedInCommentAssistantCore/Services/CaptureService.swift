import AppKit
import Foundation
@preconcurrency import ScreenCaptureKit

@MainActor
public final class CaptureService {
    private let screenSelectionCropper: ScreenSelectionCropper

    public static let supportedBrowserBundleIDs: Set<String> = [
        "com.brave.Browser",
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser"
    ]

    public init(screenSelectionCropper: ScreenSelectionCropper = ScreenSelectionCropper()) {
        self.screenSelectionCropper = screenSelectionCropper
    }

    public func captureFrontmostBrowserWindow(preferredBundleIdentifier: String? = nil) async throws -> CapturedWindow {
        guard CGPreflightScreenCaptureAccess() else {
            throw AppError.screenRecordingPermissionDenied
        }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let frontmostBundleIdentifier = frontmostApp?.bundleIdentifier

        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let supportedWindows = shareableContent.windows.filter { window in
            guard let bundleIdentifier = window.owningApplication?.bundleIdentifier else {
                return false
            }

            return Self.supportedBrowserBundleIDs.contains(bundleIdentifier) &&
            window.windowLayer == 0 &&
            window.frame.width > 600 &&
            window.frame.height > 400
        }

        guard !supportedWindows.isEmpty else {
            if let frontmostApp, let name = frontmostApp.localizedName {
                throw AppError.unsupportedFrontmostApplication(name)
            }
            throw AppError.noEligibleWindow
        }

        let candidateBundleIdentifiers = [
            frontmostBundleIdentifier.flatMap { Self.supportedBrowserBundleIDs.contains($0) ? $0 : nil },
            preferredBundleIdentifier.flatMap { Self.supportedBrowserBundleIDs.contains($0) ? $0 : nil }
        ]
        .compactMap { $0 }

        guard !candidateBundleIdentifiers.isEmpty else {
            let appName = frontmostApp?.localizedName ?? "The current app"
            throw AppError.unsupportedFrontmostApplication(appName)
        }

        let targetBundleIdentifier = candidateBundleIdentifiers.first(where: { candidate in
            supportedWindows.contains(where: { $0.owningApplication?.bundleIdentifier == candidate })
        })

        let eligibleWindows = supportedWindows.filter { window in
            window.owningApplication?.bundleIdentifier == targetBundleIdentifier
        }

        guard let selectedWindow = eligibleWindows.max(by: { $0.frame.area < $1.frame.area }) else {
            throw AppError.noEligibleWindow
        }

        guard let display = display(containing: selectedWindow.frame, in: shareableContent.displays) else {
            throw AppError.noEligibleWindow
        }

        let filter = SCContentFilter(display: display, including: [selectedWindow])
        let configuration = SCStreamConfiguration()
        configuration.showsCursor = false

        let maxCaptureDimension = 4000
        let rawWidth = Int(selectedWindow.frame.width * 2)
        let rawHeight = Int(selectedWindow.frame.height * 2)
        if max(rawWidth, rawHeight) > maxCaptureDimension {
            let scale = Double(maxCaptureDimension) / Double(max(rawWidth, rawHeight))
            configuration.width = Int(Double(rawWidth) * scale)
            configuration.height = Int(Double(rawHeight) * scale)
        } else {
            configuration.width = rawWidth
            configuration.height = rawHeight
        }

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let selectedAppName = selectedWindow.owningApplication?.applicationName ?? frontmostApp?.localizedName ?? "Browser"
        let selectedBundleIdentifier = selectedWindow.owningApplication?.bundleIdentifier ?? targetBundleIdentifier ?? frontmostBundleIdentifier ?? ""

        return CapturedWindow(
            image: image,
            windowFrame: selectedWindow.frame,
            windowID: selectedWindow.windowID,
            appName: selectedAppName,
            bundleIdentifier: selectedBundleIdentifier
        )
    }

    public func captureScreenSelection(_ selectionFrame: CGRect) throws -> CapturedWindow {
        guard CGPreflightScreenCaptureAccess() else {
            throw AppError.screenRecordingPermissionDenied
        }

        let resolvedSelection = selectionFrame.standardized.integral
        guard
            let screen = NSScreen.screens.max(
                by: { $0.frame.intersection(resolvedSelection).area < $1.frame.intersection(resolvedSelection).area }
            ),
            screen.frame.intersects(resolvedSelection)
        else {
            throw AppError.readingSelectionOutsideWindow
        }

        guard
            let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
            throw AppError.unsupportedEnvironment("The display identifier for this screen is unavailable.")
        }

        let displayID = CGDirectDisplayID(displayNumber.uint32Value)
        guard let displayImage = CGDisplayCreateImage(displayID) else {
            throw AppError.unsupportedEnvironment("The selected screen could not be captured.")
        }

        guard let croppedImage = screenSelectionCropper.crop(
            image: displayImage,
            selectionFrame: resolvedSelection,
            inWindowFrame: screen.frame
        ) else {
            throw AppError.readingSelectionOutsideWindow
        }

        return CapturedWindow(
            image: croppedImage,
            windowFrame: resolvedSelection.intersection(screen.frame),
            windowID: 0,
            appName: "Reading Selection",
            bundleIdentifier: "screen.selection"
        )
    }

    private func display(containing frame: CGRect, in displays: [SCDisplay]) -> SCDisplay? {
        displays.max { lhs, rhs in
            lhs.frame.intersection(frame).area < rhs.frame.intersection(frame).area
        }
    }
}
