import AppKit
import Combine
import CoreGraphics
import Foundation
import NaturalLanguage

@MainActor
public final class AppModel: ObservableObject {
    public enum LocalProviderHealth: Equatable {
        case unknown
        case checking
        case ready
        case unavailable(String)
        case modelMissing(String)
        case invalidEndpoint(String)
        case resourceRisk(String)
    }

    public static let shared = AppModel()

    @Published public var settings: AppSettings {
        didSet {
            persistSettings()
            styleCorpus = styleCorpusProcessor.process(rawText: settings.styleCorpusRawText)
            hotKeyMonitor.register(settings.hotKey)

            if oldValue.provider.kind != settings.provider.kind, settings.provider.kind == .ollama {
                refreshProviderHealth()
            }
        }
    }

    @Published public private(set) var personaProfile: PersonaProfile?
    @Published public private(set) var styleCorpus: [StyleCorpusEntry]
    @Published public private(set) var permissionState: PermissionState = .unknown
    @Published public private(set) var hasStoredAPIKey: Bool = false
    @Published public private(set) var scanResult: ScanResult?
    @Published public private(set) var generatedCandidates: [GeneratedCandidate] = []
    @Published public private(set) var isScanning = false
    @Published public private(set) var isGenerating = false
    @Published public var editablePostText: String = ""
    @Published public var selectedIntent: CommentIntent
    @Published public var selectedLanguage: CommentLanguage
    @Published public var customLanguageInput: String
    @Published public var uniqueThought: String = ""
    @Published public var errorMessage: String?
    @Published public var statusMessage: String?
    @Published public var isCropSheetPresented = false
    @Published public var isOverlayExpanded = true
    @Published public private(set) var isReadingModeActive = false
    @Published public private(set) var readingSelectionFrame: CGRect?
    @Published public private(set) var localProviderHealth: LocalProviderHealth = .unknown
    @Published public private(set) var availableOllamaModels: [String] = []

    public var onPresentCompanion: ((CGRect?) -> Void)?
    public var onDismissCompanion: (() -> Void)?
    public var onOpenSettingsWindow: (() -> Void)?
    public var onPresentReadingMode: ((CGRect?) -> Void)?
    public var onDismissReadingMode: (() -> Void)?

    private let settingsStore: SettingsStore
    private let keychainService: KeychainService
    private let apiKeyFileParser: APIKeyFileParser
    private let personaParser: PersonaProfileParser
    private let styleCorpusProcessor: StyleCorpusProcessor
    private let permissionService: PermissionService
    private let captureService: CaptureService
    private let ocrService: OCRService
    private let classifier: LinkedInContextClassifier
    private let postSegmentationService: PostSegmentationService
    private let commentGenerator: CommentGeneratorService
    private let clipboardService: ClipboardService
    private let hotKeyMonitor: HotKeyMonitor
    private var activeGenerationTask: Task<Void, Never>?
    private var activeScanTask: Task<Void, Never>?
    private var activationObserver: NSObjectProtocol?
    private var appDidBecomeActiveObserver: NSObjectProtocol?
    private var lastCompanionAnchorFrame: CGRect?
    private var lastKnownSupportedBrowserBundleIdentifier: String?

    public init(
        settingsStore: SettingsStore = SettingsStore(),
        keychainService: KeychainService = KeychainService(),
        apiKeyFileParser: APIKeyFileParser = APIKeyFileParser(),
        personaParser: PersonaProfileParser = PersonaProfileParser(),
        styleCorpusProcessor: StyleCorpusProcessor = StyleCorpusProcessor(),
        permissionService: PermissionService = PermissionService(),
        captureService: CaptureService = CaptureService(),
        ocrService: OCRService = OCRService(),
        classifier: LinkedInContextClassifier = LinkedInContextClassifier(),
        postSegmentationService: PostSegmentationService = PostSegmentationService(),
        commentGenerator: CommentGeneratorService = ProviderRoutingCommentGeneratorService(),
        clipboardService: ClipboardService = ClipboardService(),
        hotKeyMonitor: HotKeyMonitor = HotKeyMonitor()
    ) {
        let loadedSettings = settingsStore.loadSettings()
        self.settings = loadedSettings
        self.personaProfile = nil
        self.styleCorpusProcessor = styleCorpusProcessor
        self.styleCorpus = styleCorpusProcessor.process(rawText: loadedSettings.styleCorpusRawText)
        self.selectedIntent = loadedSettings.defaultIntent
        self.selectedLanguage = loadedSettings.defaultLanguage
        self.customLanguageInput = loadedSettings.customLanguageName
        self.readingSelectionFrame = loadedSettings.readingSelectionFrame?.standardized.integral
        self.settingsStore = settingsStore
        self.keychainService = keychainService
        self.apiKeyFileParser = apiKeyFileParser
        self.personaParser = personaParser
        self.permissionService = permissionService
        self.captureService = captureService
        self.ocrService = ocrService
        self.classifier = classifier
        self.postSegmentationService = postSegmentationService
        self.commentGenerator = commentGenerator
        self.clipboardService = clipboardService
        self.hotKeyMonitor = hotKeyMonitor
    }

    public var canGenerate: Bool {
        generationBlockers.isEmpty && !isGenerating
    }

    public var currentWarnings: [String] {
        scanResult?.warnings ?? []
    }

    public var generationBlockers: [String] {
        var blockers: [String] = []

        if settings.provider.kind == .openAI && !hasStoredAPIKey {
            blockers.append("save an OpenAI API key")
        }

        if settings.provider.kind == .ollama {
            switch localProviderHealth {
            case .unavailable, .modelMissing, .invalidEndpoint:
                blockers.append("fix the local Ollama provider status in Settings")
            case .unknown, .checking, .ready, .resourceRisk:
                break
            }
        }

        if editablePostText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blockers.append("scan or paste post text")
        }

        return blockers
    }

    public var generationReadinessMessage: String? {
        guard !generationBlockers.isEmpty else { return nil }
        return "To generate comments, \(generationBlockers.joined(separator: " and "))."
    }

    public var isUsingImportedPersona: Bool {
        settings.personaFilePath != nil
    }

    public var activeProviderDisplayName: String {
        settings.provider.kind.displayName
    }

    public var isProviderReady: Bool {
        switch settings.provider.kind {
        case .openAI:
            return hasStoredAPIKey
        case .ollama:
            switch localProviderHealth {
            case .ready, .unknown, .checking, .resourceRisk:
                return true
            case .unavailable, .modelMissing, .invalidEndpoint:
                return false
            }
        }
    }

    public var localProviderHealthMessage: String {
        switch localProviderHealth {
        case .unknown:
            return "Local provider status has not been checked yet."
        case .checking:
            return "Checking local provider availability…"
        case .ready:
            return "Local provider is reachable and model \(settings.provider.ollamaModel) is available."
        case .unavailable(let details):
            return details
        case .modelMissing(let details):
            return details
        case .invalidEndpoint(let details):
            return details
        case .resourceRisk(let details):
            return details
        }
    }

    public var overlayEdge: OverlayEdge {
        settings.overlayEdge
    }

    public var overlayPanelSize: CGSize {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        if !isOverlayExpanded {
            return CGSize(width: 28, height: screenHeight)
        }
        return CGSize(width: 340, height: screenHeight)
    }

    public func start() {
        refreshPermissionState()
        loadPersonaIfAvailable()
        hasStoredAPIKey = keychainService.loadAPIKey() != nil
        refreshProviderHealth()
        startObservingApplicationActivation()
        startTrackingActiveApplications()

        hotKeyMonitor.onTrigger = { [weak self] in
            Task { @MainActor in
                self?.triggerScan()
            }
        }
        hotKeyMonitor.register(settings.hotKey)

        presentCurrentCompanion()

        if shouldShowOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.openSettingsWindow()
            }
        }
    }

    public func triggerScan() {
        activeScanTask?.cancel()
        activeScanTask = Task { @MainActor in
            await self.scanVisibleFeed(selectionRect: self.isReadingModeActive ? self.readingSelectionFrame : nil)
        }
    }

    public func triggerReadingSelectionScan() {
        activeScanTask?.cancel()
        activeScanTask = Task { @MainActor in
            guard self.readingSelectionFrame != nil else {
                self.errorMessage = AppError.missingReadingSelection.localizedDescription
                return
            }
            await self.scanVisibleFeed(selectionRect: self.readingSelectionFrame)
        }
    }

    public func triggerGenerate() {
        guard !isGenerating else { return }
        activeGenerationTask = Task { @MainActor in
            await self.generateComments()
        }
    }

    public func triggerScanAndGenerate() {
        guard !isGenerating else { return }
        activeGenerationTask = Task { @MainActor in
            await self.scanThenGenerate()
        }
    }

    public func cancelGeneration() {
        activeGenerationTask?.cancel()
        activeGenerationTask = nil
        statusMessage = "Generation cancelled."
    }

    public var resolvedPersona: PersonaProfile {
        personaProfile ?? builtInPersonaProfile()
    }

    public var resourceWarning: String? {
        if case .resourceRisk(let message) = localProviderHealth {
            return message
        }
        return nil
    }

    public func refreshProviderHealth() {
        Task { @MainActor in
            await evaluateProviderHealth()
        }
    }

    public func refreshPermissionState() {
        permissionState = permissionService.currentScreenRecordingState()
        markOnboardingCompletedIfReady()
    }

    public func requestScreenRecordingAccess() {
        permissionState = permissionService.requestScreenRecordingAccess()
        markOnboardingCompletedIfReady()
    }

    public func openScreenRecordingPreferences() {
        permissionService.openScreenRecordingSettings()
    }

    public func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        onOpenSettingsWindow?()
    }

    public func enterReadingMode() {
        isReadingModeActive = true
        statusMessage = "Reading mode enabled. Scroll normally, adjust the box, then scan only the text inside it."
        onPresentReadingMode?(lastCompanionAnchorFrame)
    }

    public func exitReadingMode() {
        isReadingModeActive = false
        statusMessage = "Reading mode closed."
        onDismissReadingMode?()
    }

    public func toggleReadingMode() {
        if isReadingModeActive {
            exitReadingMode()
        } else {
            enterReadingMode()
        }
    }

    public func updateReadingSelection(_ frame: CGRect) {
        let normalizedFrame = frame.standardized.integral
        readingSelectionFrame = normalizedFrame

        guard settings.readingSelectionFrame != normalizedFrame else {
            return
        }

        var copy = settings
        copy.readingSelectionFrame = normalizedFrame
        settings = copy
    }

    public func relaunchApplication() {
        let bundleURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        statusMessage = "Relaunching to refresh macOS permissions…"

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                if let error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    public func saveAPIKey(_ apiKey: String) {
        do {
            try keychainService.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            hasStoredAPIKey = true
            statusMessage = "API key saved to Keychain."
            errorMessage = nil
            markOnboardingCompletedIfReady()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func importAPIKey(from url: URL) {
        do {
            let apiKey = try apiKeyFileParser.parse(url: url)
            saveAPIKey(apiKey)
            statusMessage = "API key imported from file and saved to Keychain."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func removeAPIKey() {
        keychainService.deleteAPIKey()
        hasStoredAPIKey = false
    }

    public func importPersona(from url: URL) {
        do {
            let importedURL = try settingsStore.importPersonaFile(from: url)
            personaProfile = try personaParser.parse(url: importedURL)
            settings.personaFilePath = importedURL.path
            statusMessage = "Loaded persona profile \(personaProfile?.name ?? "")."
            errorMessage = nil
            markOnboardingCompletedIfReady()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func importContextFile(from url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw AppError.generationFailed("Could not access the selected file.")
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let content = try String(contentsOf: url, encoding: .utf8)
            var copy = settings
            copy.additionalPromptContext = content
            settings = copy
            statusMessage = "Imported \(url.lastPathComponent) into global prompt context."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clearPersona() {
        personaProfile = builtInPersonaProfile()
        settings.personaFilePath = nil
        statusMessage = "Reverted to the built-in persona."
        errorMessage = nil
    }

    public func useBuiltInPersona() {
        clearPersona()
    }

    public func presentCurrentCompanion() {
        onPresentCompanion?(lastCompanionAnchorFrame)
    }

    public func dismissCompanion() {
        isOverlayExpanded = false
        presentCurrentCompanion()
    }

    public func presentCropSheet() {
        guard scanResult != nil else { return }
        isCropSheetPresented = true
    }

    public func applyManualCrop(_ croppedImage: CGImage) {
        do {
            let ocrResult = try ocrService.recognizeText(in: croppedImage)
            let filteredBlocks = postSegmentationService.feedCandidateBlocks(
                from: ocrResult.blocks,
                imageSize: CGSize(width: ocrResult.processedImage.width, height: ocrResult.processedImage.height)
            )
            let regionBlocks = postSegmentationService.feedRegionBlocks(
                from: ocrResult.blocks,
                imageSize: CGSize(width: ocrResult.processedImage.width, height: ocrResult.processedImage.height)
            )
            let analysisBlocks = regionBlocks.isEmpty ? filteredBlocks : regionBlocks
            let extractedText = postSegmentationService.joinedText(from: analysisBlocks.isEmpty ? ocrResult.blocks : analysisBlocks)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !extractedText.isEmpty else {
                throw AppError.cropFailed
            }

            editablePostText = extractedText
            generatedCandidates = []
            isCropSheetPresented = false
            statusMessage = "Manual crop applied. Review the extracted text before generating."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func switchProvider(to kind: ProviderKind) {
        guard settings.provider.kind != kind else { return }
        var copy = settings
        copy.provider.kind = kind
        settings = copy
    }

    public func copy(candidate: GeneratedCandidate) {
        clipboardService.copy(candidate.text)
        statusMessage = "Copied candidate to clipboard."

        if settings.collapseAfterCopy {
            isOverlayExpanded = false
            presentCurrentCompanion()
        }
    }

    public func copyBestCandidate() {
        guard let best = generatedCandidates.first else { return }
        copy(candidate: best)
    }

    public func toggleOverlayExpanded() {
        isOverlayExpanded.toggle()
        presentCurrentCompanion()
    }

    public func setOverlayEdge(_ edge: OverlayEdge) {
        guard settings.overlayEdge != edge else { return }
        var copy = settings
        copy.overlayEdge = edge
        settings = copy
        presentCurrentCompanion()
    }

    public func moveOverlay(by verticalDelta: CGFloat) {
        guard let screen = preferredOverlayScreen() else { return }
        let visibleFrame = screen.visibleFrame.insetBy(dx: 12, dy: 24)
        let travel = max(visibleFrame.height - overlayPanelSize.height, 1)
        let ratioDelta = Double(verticalDelta / travel)
        var copy = settings
        copy.overlayVerticalPosition = min(max(copy.overlayVerticalPosition + ratioDelta, 0), 1)
        settings = copy
        presentCurrentCompanion()
    }

    private func scanVisibleFeed(selectionRect: CGRect? = nil) async {
        isScanning = true
        scanResult = nil
        generatedCandidates = []
        errorMessage = nil
        statusMessage = selectionRect == nil
            ? "Scanning the visible browser window…"
            : "Scanning the selected reading region…"
        presentCurrentCompanion()

        defer { isScanning = false }

        do {
            if let selectionFrame = selectionRect?.standardized.integral {
                try await scanReadingSelection(selectionFrame)
            } else {
                try await scanVisibleBrowserFeed()
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
            onPresentCompanion?(lastCompanionAnchorFrame)
        }
    }

    private func scanThenGenerate() async {
        await scanVisibleFeed(selectionRect: isReadingModeActive ? readingSelectionFrame : nil)

        guard generationBlockers.isEmpty else {
            if errorMessage == nil {
                statusMessage = generationReadinessMessage
            }
            return
        }

        await generateComments()
    }

    private func scanReadingSelection(_ selectionFrame: CGRect) async throws {
        updateReadingSelection(selectionFrame)

        let capturedSelection = try captureService.captureScreenSelection(selectionFrame)
        let ocrResult = try ocrService.recognizeText(in: capturedSelection.image)
        let extractedText = ocrResult.concatenatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !extractedText.isEmpty else {
            throw AppError.emptyPostText
        }

        let imageSize = CGSize(width: ocrResult.processedImage.width, height: ocrResult.processedImage.height)
        let classification = classifier.classify(blocks: ocrResult.blocks, imageSize: imageSize)
        let syntheticPost = DetectedPost(
            text: extractedText,
            frame: CGRect(origin: .zero, size: imageSize),
            score: 1,
            averageConfidence: ocrResult.averageConfidence,
            anchors: classification.anchors,
            warnings: []
        )

        let processedCapture = CapturedWindow(
            image: ocrResult.processedImage,
            windowFrame: capturedSelection.windowFrame,
            windowID: capturedSelection.windowID,
            appName: capturedSelection.appName,
            bundleIdentifier: capturedSelection.bundleIdentifier
        )

        self.scanResult = ScanResult(
            capturedWindow: processedCapture,
            ocrBlocks: ocrResult.blocks,
            allText: extractedText,
            linkedInConfidence: max(classification.confidence, 0.85),
            dominantPost: syntheticPost,
            alternatePosts: [],
            warnings: [],
            overallConfidence: ocrResult.averageConfidence
        )
        self.editablePostText = extractedText
        self.lastCompanionAnchorFrame = capturedSelection.windowFrame
        self.errorMessage = ocrResult.averageConfidence < 0.55
            ? "OCR confidence is low. Review the extracted text before generating."
            : nil
        self.statusMessage = "Selection scan complete. Only text inside the reading box was processed."
        self.onPresentCompanion?(capturedSelection.windowFrame)
    }

    private func scanVisibleBrowserFeed() async throws {
        let capturedWindow = try await captureService.captureFrontmostBrowserWindow(
            preferredBundleIdentifier: lastKnownSupportedBrowserBundleIdentifier
        )
        let ocrResult = try ocrService.recognizeText(in: capturedWindow.image)
        let imageSize = CGSize(width: ocrResult.processedImage.width, height: ocrResult.processedImage.height)
        let feedBlocks = postSegmentationService.feedCandidateBlocks(from: ocrResult.blocks, imageSize: imageSize)
        let feedRegionBlocks = postSegmentationService.feedRegionBlocks(from: ocrResult.blocks, imageSize: imageSize)
        let analysisBlocks = feedRegionBlocks.isEmpty ? feedBlocks : feedRegionBlocks
        let classification = classifier.classify(
            blocks: analysisBlocks.isEmpty ? ocrResult.blocks : analysisBlocks,
            imageSize: imageSize
        )
        let posts = postSegmentationService.detectPosts(
            from: analysisBlocks.isEmpty ? ocrResult.blocks : analysisBlocks,
            imageSize: imageSize,
            linkedInConfidence: classification.confidence,
            classifier: classifier
        )

        let processedCapture = CapturedWindow(
            image: ocrResult.processedImage,
            windowFrame: capturedWindow.windowFrame,
            windowID: capturedWindow.windowID,
            appName: capturedWindow.appName,
            bundleIdentifier: capturedWindow.bundleIdentifier
        )

        let warnings = Array(Set(classification.warnings + posts.warnings + (posts.dominantPost?.warnings ?? []))).sorted()
        let fallbackText = postSegmentationService.joinedText(from: analysisBlocks.isEmpty ? ocrResult.blocks : analysisBlocks)
        let scanResult = ScanResult(
            capturedWindow: processedCapture,
            ocrBlocks: analysisBlocks.isEmpty ? ocrResult.blocks : analysisBlocks,
            allText: fallbackText,
            linkedInConfidence: classification.confidence,
            dominantPost: posts.dominantPost,
            alternatePosts: posts.alternatePosts,
            warnings: warnings,
            overallConfidence: min(ocrResult.averageConfidence, classification.confidence)
        )

        self.scanResult = scanResult
        self.editablePostText = posts.dominantPost?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? fallbackText
        self.lastCompanionAnchorFrame = capturedWindow.windowFrame

        if ocrResult.averageConfidence < 0.55 {
            self.errorMessage = "OCR confidence is low. Review or crop the extracted text before generating."
        }

        if posts.dominantPost == nil {
            self.errorMessage = AppError.lowConfidencePostDetection.localizedDescription
        }

        self.statusMessage = "Scan complete. Review the extracted post and generate when ready."
        self.onPresentCompanion?(capturedWindow.windowFrame)
    }

    private func generateComments() async {
        guard !Task.isCancelled else { return }

        let personaProfile = resolvedPersona

        let apiKey: String?
        switch settings.provider.kind {
        case .openAI:
            guard let storedAPIKey = keychainService.loadAPIKey(), !storedAPIKey.isEmpty else {
                errorMessage = AppError.missingAPIKey.localizedDescription
                return
            }
            apiKey = storedAPIKey
        case .ollama:
            await evaluateProviderHealth()
            switch localProviderHealth {
            case .ready, .unknown, .resourceRisk:
                break
            case .checking:
                errorMessage = "Local provider check is still running. Try again in a moment."
                return
            case .unavailable, .modelMissing, .invalidEndpoint:
                errorMessage = localProviderHealthMessage
                return
            }
            apiKey = nil
        }

        let postText = editablePostText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !postText.isEmpty else {
            errorMessage = AppError.emptyPostText.localizedDescription
            return
        }

        isGenerating = true
        errorMessage = nil
        statusMessage = "Generating comment candidates…"
        generatedCandidates = []
        presentCurrentCompanion()

        defer { isGenerating = false }

        let selectedExamples = styleCorpusProcessor.selectRelevantExamples(
            from: styleCorpus,
            for: postText,
            preferredLanguage: resolvedExampleLanguageCode()
        )

        let detectedLanguage = detectPostLanguage(postText)

        let request = GenerationRequest(
            postText: postText,
            ocrConfidence: scanResult?.overallConfidence ?? 0,
            languageSelection: selectedLanguage,
            customLanguage: customLanguageInput,
            detectedLanguageName: detectedLanguage,
            intent: selectedIntent,
            uniqueThought: uniqueThought,
            personaProfile: personaProfile,
            styleExamples: selectedExamples,
            additionalPromptContext: settings.additionalPromptContext
        )

        do {
            let generated = try await commentGenerator.generate(
                request: request,
                apiKey: apiKey,
                provider: settings.provider
            )
            guard !Task.isCancelled else { return }
            generatedCandidates = generated
            statusMessage = "Generated 3 candidate comments."
            onPresentCompanion?(lastCompanionAnchorFrame)
        } catch is CancellationError {
            statusMessage = "Generation cancelled."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPersonaIfAvailable() {
        guard let personaFilePath = settings.personaFilePath else {
            personaProfile = builtInPersonaProfile()
            return
        }

        do {
            personaProfile = try personaParser.parse(url: URL(fileURLWithPath: personaFilePath))
        } catch {
            personaProfile = builtInPersonaProfile()
            errorMessage = error.localizedDescription
        }
    }

    private func persistSettings() {
        do {
            try settingsStore.saveSettings(settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markOnboardingCompletedIfReady() {
        let providerReady: Bool
        switch settings.provider.kind {
        case .openAI:
            providerReady = hasStoredAPIKey
        case .ollama:
            providerReady = isProviderReady
        }

        let ready = permissionState == .granted && providerReady
        if ready && !settings.firstLaunchCompleted {
            settings.firstLaunchCompleted = true
        }
    }

    private var shouldShowOnboarding: Bool {
        let providerNeedsSetup = settings.provider.kind == .openAI && !hasStoredAPIKey
        return !settings.firstLaunchCompleted || permissionState != .granted || providerNeedsSetup
    }

    private func resolvedExampleLanguageCode() -> String? {
        switch selectedLanguage {
        case .english:
            return "en"
        case .spanish:
            return "es"
        case .custom:
            return nil
        case .sameAsPost:
            return nil
        }
    }

    private func startTrackingActiveApplications() {
        guard activationObserver == nil else { return }
        let supportedBrowsers = CaptureService.supportedBrowserBundleIDs

        if let currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           supportedBrowsers.contains(currentBundleID) {
            lastKnownSupportedBrowserBundleIdentifier = currentBundleID
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let bundleIdentifier = application.bundleIdentifier,
                supportedBrowsers.contains(bundleIdentifier)
            else {
                return
            }

            Task { @MainActor [weak self] in
                self?.lastKnownSupportedBrowserBundleIdentifier = bundleIdentifier
            }
        }
    }

    private func startObservingApplicationActivation() {
        guard appDidBecomeActiveObserver == nil else { return }

        appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleApplicationDidBecomeActive()
            }
        }
    }

    private func handleApplicationDidBecomeActive() {
        let previousPermissionState = permissionState
        refreshPermissionState()
        hasStoredAPIKey = keychainService.loadAPIKey() != nil

        if previousPermissionState != permissionState, permissionState == .granted {
            statusMessage = "Screen Recording permission updated."
            if errorMessage == AppError.screenRecordingPermissionDenied.localizedDescription {
                errorMessage = nil
            }
        }
    }

    private func preferredOverlayScreen() -> NSScreen? {
        if let frame = lastCompanionAnchorFrame {
            return NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main
        }

        return NSScreen.main
    }

    private func detectPostLanguage(_ text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage, language != .undetermined else {
            return nil
        }
        return Locale.current.localizedString(forLanguageCode: language.rawValue)
    }

    private func builtInPersonaProfile() -> PersonaProfile {
        PersonaProfile(
            name: "Built-In Persona",
            defaultLanguage: "English",
            defaultIntent: .agree,
            maxCommentSentences: 3,
            voice: "Concise, specific, and credible. Sound like a thoughtful professional rather than a hype account.",
            tone: "Warm, clear, and grounded in the post.",
            doRules: [
                "Reference one concrete idea from the post before adding your own angle.",
                "Keep comments natural and useful."
            ],
            avoidRules: [
                "Do not use generic praise with no substance.",
                "Do not sound automated or overuse emojis and hashtags."
            ]
        )
    }

    private func evaluateProviderHealth() async {
        guard settings.provider.kind == .ollama else {
            localProviderHealth = .unknown
            return
        }

        let endpoint = settings.provider.ollamaBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelName = settings.provider.ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !modelName.isEmpty else {
            localProviderHealth = .modelMissing("Set an Ollama model name before generating comments.")
            return
        }

        guard var components = URLComponents(string: endpoint), components.scheme != nil else {
            localProviderHealth = .invalidEndpoint("Ollama endpoint is invalid. Use a full URL like http://127.0.0.1:11434/api/generate.")
            return
        }

        components.path = "/api/tags"
        components.query = nil
        components.fragment = nil

        guard let tagsURL = components.url else {
            localProviderHealth = .invalidEndpoint("Ollama endpoint is invalid. Use a full URL like http://127.0.0.1:11434/api/generate.")
            return
        }

        localProviderHealth = .checking

        var request = URLRequest(url: tagsURL)
        request.timeoutInterval = 3

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                localProviderHealth = .unavailable("Local provider check failed: invalid HTTP response from \(tagsURL.absoluteString).")
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                localProviderHealth = .unavailable("Ollama health check returned HTTP \(httpResponse.statusCode). Verify the local server is running.")
                return
            }

            let payload = try JSONDecoder().decode(OllamaTagsEnvelope.self, from: data)
            availableOllamaModels = payload.models.map(\.name)
            let installedModels = payload.models.map { $0.name.lowercased() }
            let requestedModel = modelName.lowercased()

            if installedModels.contains(requestedModel) {
                guard let installedModel = payload.models.first(where: { $0.name.lowercased() == requestedModel }) else {
                    localProviderHealth = .ready
                    return
                }

                let descriptor = OllamaModelDescriptor(
                    name: installedModel.name,
                    sizeBytes: installedModel.size,
                    parameterSize: installedModel.details?.parameterSize
                )

                switch OllamaModelSafetyEvaluator.evaluate(descriptor) {
                case .safe:
                    localProviderHealth = .ready
                case .risky(let message):
                    localProviderHealth = .resourceRisk(message)
                }
            } else {
                let sample = payload.models.prefix(4).map(\.name).joined(separator: ", ")
                let suffix = sample.isEmpty ? "" : " Installed models include: \(sample)."
                localProviderHealth = .modelMissing("Model \(modelName) is not available in Ollama.\(suffix)")
            }
        } catch let urlError as URLError {
            localProviderHealth = .unavailable("Cannot reach Ollama at \(tagsURL.absoluteString): \(urlError.localizedDescription)")
        } catch {
            localProviderHealth = .unavailable("Local provider check failed: \(error.localizedDescription)")
        }
    }

    private struct OllamaTagsEnvelope: Decodable {
        var models: [OllamaListedModel]
    }

    private struct OllamaListedModel: Decodable {
        var name: String
        var size: Int64?
        var details: OllamaListedModelDetails?
    }

    private struct OllamaListedModelDetails: Decodable {
        var parameterSize: String?

        enum CodingKeys: String, CodingKey {
            case parameterSize = "parameter_size"
        }
    }
}
