import AppKit
import CoreGraphics
import Foundation

@MainActor
public final class PermissionService {
    public init() {}

    public func currentScreenRecordingState() -> PermissionState {
        CGPreflightScreenCaptureAccess() ? .granted : .denied
    }

    @discardableResult
    public func requestScreenRecordingAccess() -> PermissionState {
        CGRequestScreenCaptureAccess() ? .granted : .denied
    }

    public func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
