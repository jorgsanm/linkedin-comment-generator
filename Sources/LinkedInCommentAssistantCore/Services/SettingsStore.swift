import Foundation

public final class SettingsStore {
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func loadSettings() -> AppSettings {
        do {
            let data = try Data(contentsOf: settingsFileURL())
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            return AppSettings()
        }
    }

    public func saveSettings(_ settings: AppSettings) throws {
        let directoryURL = try applicationSupportDirectory()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(settings)
        try data.write(to: settingsFileURL(), options: .atomic)
    }

    public func importPersonaFile(from sourceURL: URL) throws -> URL {
        let importedDirectory = try applicationSupportDirectory().appendingPathComponent("Imported", isDirectory: true)
        try fileManager.createDirectory(at: importedDirectory, withIntermediateDirectories: true)

        let startedAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if startedAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileExtension = sourceURL.pathExtension.isEmpty ? "md" : sourceURL.pathExtension
        let destinationURL = importedDirectory.appendingPathComponent("persona-profile.\(fileExtension)", isDirectory: false)
        let data = try Data(contentsOf: sourceURL)
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    public func applicationSupportDirectory() throws -> URL {
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AppError.unsupportedEnvironment("Application Support is unavailable on this system.")
        }

        return baseURL.appendingPathComponent("LinkedInCommentAssistant", isDirectory: true)
    }

    private func settingsFileURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("settings.json", isDirectory: false)
    }
}
