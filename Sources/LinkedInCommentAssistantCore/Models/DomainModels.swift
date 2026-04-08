import CoreGraphics
import Foundation

public enum CommentIntent: String, CaseIterable, Codable, Identifiable, Sendable {
    case free
    case agree
    case disagree
    case askQuestion
    case congratulate

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .free:
            return "Free to choose"
        case .agree:
            return "Agree"
        case .disagree:
            return "Disagree"
        case .askQuestion:
            return "Ask Question"
        case .congratulate:
            return "Congratulate"
        }
    }

    /// Per-intent prompt guidance block appended near the end of the LLM
    /// instructions so it has strong recency weight. Small models sometimes
    /// ignore a one-line intent mention; this block gives them explicit,
    /// concrete rules for each stance.
    public var promptGuidance: String {
        switch self {
        case .free:
            return "Choose whichever stance — agree, disagree, ask a question, congratulate, or add perspective — best fits the post on its own merits. Do NOT default to agreement. Pick what a thoughtful reader would actually say."
        case .agree:
            return "ALL 3 comments must express genuine agreement with a specific, concrete point made in the post. Name the specific idea you're agreeing with. Do NOT just add generic praise like 'great post'."
        case .disagree:
            return "ALL 3 comments must respectfully challenge or add a counterpoint to something specific the post claims. Be constructive, not hostile. Each must clearly be a disagreement, not a mild caveat."
        case .askQuestion:
            return "ALL 3 comments MUST be phrased as actual questions directed at the author or audience. Every single comment text MUST contain at least one question mark ('?') and MUST be a real question, not a statement with a tag question tacked on. No declarative comments."
        case .congratulate:
            return "ALL 3 comments must congratulate the author on the specific achievement, milestone, or launch described in the post. Name what you're congratulating them on. Do NOT ask questions or disagree."
        }
    }

    public init?(slug: String) {
        let normalized = slug
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        switch normalized {
        case "free", "free to choose", "any", "auto", "none":
            self = .free
        case "agree":
            self = .agree
        case "disagree":
            self = .disagree
        case "ask question", "question", "ask":
            self = .askQuestion
        case "congratulate", "congrats", "congratulations":
            self = .congratulate
        default:
            return nil
        }
    }
}

public enum CommentLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case sameAsPost
    case english
    case spanish
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sameAsPost:
            return "Same as post"
        case .english:
            return "English"
        case .spanish:
            return "Spanish"
        case .custom:
            return "Custom…"
        }
    }
}

public enum PermissionState: String, Codable, Sendable {
    case unknown
    case granted
    case denied
}

public enum CommentLengthCategory: String, Codable, CaseIterable, Sendable {
    case short
    case medium
    case expanded
}

public enum OverlayEdge: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case right

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .left:
            return "Left"
        case .right:
            return "Right"
        }
    }
}

public enum ProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI
    case ollama

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .ollama:
            return "Local (Ollama)"
        }
    }
}

public struct ProviderSettings: Codable, Equatable, Sendable {
    public static let openAIModelPresets: [String] = [
        "gpt-5.4", "gpt-5.4-pro", "gpt-5.4-mini", "gpt-5.4-nano",
        "gpt-5", "gpt-5-pro", "gpt-5-mini", "gpt-5-nano",
        "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano",
        "o3-pro", "o3", "o4-mini", "o3-mini", "o1-pro", "o1",
        "gpt-4o", "gpt-4o-mini"
    ]

    public var kind: ProviderKind
    public var openAIBaseURL: String
    public var openAIModel: String
    public var ollamaBaseURL: String
    public var ollamaModel: String

    public init(
        kind: ProviderKind = .ollama,
        openAIBaseURL: String = "https://api.openai.com/v1/responses",
        openAIModel: String = "gpt-4.1-mini",
        ollamaBaseURL: String = "http://127.0.0.1:11434/api/generate",
        ollamaModel: String = "qwen2.5:7b"
    ) {
        self.kind = kind
        self.openAIBaseURL = openAIBaseURL
        self.openAIModel = openAIModel
        self.ollamaBaseURL = ollamaBaseURL
        self.ollamaModel = ollamaModel
    }

    public var activeBaseURL: String {
        switch kind {
        case .openAI:
            return openAIBaseURL
        case .ollama:
            return ollamaBaseURL
        }
    }

    public var activeModel: String {
        switch kind {
        case .openAI:
            return openAIModel
        case .ollama:
            return ollamaModel
        }
    }
}

public struct HotKeyConfiguration: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var personaFilePath: String?
    public var styleCorpusRawText: String
    public var provider: ProviderSettings
    public var defaultIntent: CommentIntent
    public var defaultLanguage: CommentLanguage
    public var customLanguageName: String
    public var debugLoggingEnabled: Bool
    public var firstLaunchCompleted: Bool
    public var hotKey: HotKeyConfiguration
    public var overlayEdge: OverlayEdge
    public var overlayVerticalPosition: Double
    public var additionalPromptContext: String
    public var readingSelectionFrame: CGRect?

    public init(
        personaFilePath: String? = nil,
        styleCorpusRawText: String = "",
        provider: ProviderSettings = ProviderSettings(),
        defaultIntent: CommentIntent = .agree,
        defaultLanguage: CommentLanguage = .sameAsPost,
        customLanguageName: String = "",
        debugLoggingEnabled: Bool = false,
        firstLaunchCompleted: Bool = false,
        hotKey: HotKeyConfiguration = .defaultScanHotKey,
        overlayEdge: OverlayEdge = .right,
        overlayVerticalPosition: Double = 0.42,
        additionalPromptContext: String = "",
        readingSelectionFrame: CGRect? = nil
    ) {
        self.personaFilePath = personaFilePath
        self.styleCorpusRawText = styleCorpusRawText
        self.provider = provider
        self.defaultIntent = defaultIntent
        self.defaultLanguage = defaultLanguage
        self.customLanguageName = customLanguageName
        self.debugLoggingEnabled = debugLoggingEnabled
        self.firstLaunchCompleted = firstLaunchCompleted
        self.hotKey = hotKey
        self.overlayEdge = overlayEdge
        self.overlayVerticalPosition = overlayVerticalPosition
        self.additionalPromptContext = additionalPromptContext
        self.readingSelectionFrame = readingSelectionFrame
    }
}

public extension HotKeyConfiguration {
    static let defaultScanHotKey = HotKeyConfiguration(keyCode: 8, modifiers: 6144)
}

public struct PersonaProfile: Codable, Equatable, Sendable {
    public var name: String
    public var defaultLanguage: String
    public var defaultIntent: CommentIntent
    public var maxCommentSentences: Int
    public var voice: String
    public var tone: String
    public var doRules: [String]
    public var avoidRules: [String]
    public var audience: String?
    public var ctaRules: [String]
    public var bannedPhrases: [String]
    public var sourcePath: String?

    public init(
        name: String,
        defaultLanguage: String,
        defaultIntent: CommentIntent,
        maxCommentSentences: Int,
        voice: String,
        tone: String,
        doRules: [String],
        avoidRules: [String],
        audience: String? = nil,
        ctaRules: [String] = [],
        bannedPhrases: [String] = [],
        sourcePath: String? = nil
    ) {
        self.name = name
        self.defaultLanguage = defaultLanguage
        self.defaultIntent = defaultIntent
        self.maxCommentSentences = maxCommentSentences
        self.voice = voice
        self.tone = tone
        self.doRules = doRules
        self.avoidRules = avoidRules
        self.audience = audience
        self.ctaRules = ctaRules
        self.bannedPhrases = bannedPhrases
        self.sourcePath = sourcePath
    }
}

public struct StyleCorpusEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var text: String
    public var languageCode: String?
    public var fingerprint: String

    public init(
        id: UUID = UUID(),
        text: String,
        languageCode: String?,
        fingerprint: String
    ) {
        self.id = id
        self.text = text
        self.languageCode = languageCode
        self.fingerprint = fingerprint
    }
}

public struct OCRLine: Equatable, Sendable {
    public var text: String
    public var confidence: Double
    public var frame: CGRect

    public init(text: String, confidence: Double, frame: CGRect) {
        self.text = text
        self.confidence = confidence
        self.frame = frame
    }
}

public struct OCRBlock: Equatable, Sendable {
    public var lines: [OCRLine]
    public var text: String
    public var frame: CGRect
    public var averageConfidence: Double

    public init(lines: [OCRLine], text: String, frame: CGRect, averageConfidence: Double) {
        self.lines = lines
        self.text = text
        self.frame = frame
        self.averageConfidence = averageConfidence
    }
}

public struct OCRResult {
    public var processedImage: CGImage
    public var lines: [OCRLine]
    public var blocks: [OCRBlock]
    public var averageConfidence: Double
    public var concatenatedText: String

    public init(
        processedImage: CGImage,
        lines: [OCRLine],
        blocks: [OCRBlock],
        averageConfidence: Double,
        concatenatedText: String
    ) {
        self.processedImage = processedImage
        self.lines = lines
        self.blocks = blocks
        self.averageConfidence = averageConfidence
        self.concatenatedText = concatenatedText
    }
}

public struct CapturedWindow {
    public var image: CGImage
    public var windowFrame: CGRect
    public var windowID: UInt32
    public var appName: String
    public var bundleIdentifier: String

    public init(
        image: CGImage,
        windowFrame: CGRect,
        windowID: UInt32,
        appName: String,
        bundleIdentifier: String
    ) {
        self.image = image
        self.windowFrame = windowFrame
        self.windowID = windowID
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct DetectedPost: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var text: String
    public var frame: CGRect
    public var score: Double
    public var averageConfidence: Double
    public var anchors: [String]
    public var warnings: [String]

    public init(
        id: UUID = UUID(),
        text: String,
        frame: CGRect,
        score: Double,
        averageConfidence: Double,
        anchors: [String],
        warnings: [String]
    ) {
        self.id = id
        self.text = text
        self.frame = frame
        self.score = score
        self.averageConfidence = averageConfidence
        self.anchors = anchors
        self.warnings = warnings
    }
}

public struct LinkedInClassification: Equatable, Sendable {
    public var confidence: Double
    public var anchors: [String]
    public var warnings: [String]

    public init(confidence: Double, anchors: [String], warnings: [String]) {
        self.confidence = confidence
        self.anchors = anchors
        self.warnings = warnings
    }
}

public struct PostDetectionResult: Equatable, Sendable {
    public var dominantPost: DetectedPost?
    public var alternatePosts: [DetectedPost]
    public var warnings: [String]

    public init(dominantPost: DetectedPost?, alternatePosts: [DetectedPost], warnings: [String]) {
        self.dominantPost = dominantPost
        self.alternatePosts = alternatePosts
        self.warnings = warnings
    }
}

public struct ScanResult {
    public var capturedWindow: CapturedWindow
    public var ocrBlocks: [OCRBlock]
    public var allText: String
    public var linkedInConfidence: Double
    public var dominantPost: DetectedPost?
    public var alternatePosts: [DetectedPost]
    public var warnings: [String]
    public var overallConfidence: Double

    public init(
        capturedWindow: CapturedWindow,
        ocrBlocks: [OCRBlock],
        allText: String,
        linkedInConfidence: Double,
        dominantPost: DetectedPost?,
        alternatePosts: [DetectedPost],
        warnings: [String],
        overallConfidence: Double
    ) {
        self.capturedWindow = capturedWindow
        self.ocrBlocks = ocrBlocks
        self.allText = allText
        self.linkedInConfidence = linkedInConfidence
        self.dominantPost = dominantPost
        self.alternatePosts = alternatePosts
        self.warnings = warnings
        self.overallConfidence = overallConfidence
    }
}

public struct GenerationRequest: Sendable {
    public var postText: String
    public var ocrConfidence: Double
    public var languageSelection: CommentLanguage
    public var customLanguage: String
    public var detectedLanguageName: String?
    public var intent: CommentIntent
    public var uniqueThought: String
    public var personaProfile: PersonaProfile
    public var styleExamples: [StyleCorpusEntry]
    public var additionalPromptContext: String
    /// When non-nil, the assembler produces a single-candidate rework prompt
    /// that asks the model to keep the spirit/voice of the given text but
    /// write a slightly different angle.
    public var reworkTarget: String?
    /// When non-nil, the assembler appends a trailing retry-feedback block to
    /// the user message so the second attempt knows what went wrong.
    public var retryFeedback: String?

    public init(
        postText: String,
        ocrConfidence: Double,
        languageSelection: CommentLanguage,
        customLanguage: String,
        detectedLanguageName: String? = nil,
        intent: CommentIntent,
        uniqueThought: String,
        personaProfile: PersonaProfile,
        styleExamples: [StyleCorpusEntry],
        additionalPromptContext: String,
        reworkTarget: String? = nil,
        retryFeedback: String? = nil
    ) {
        self.postText = postText
        self.ocrConfidence = ocrConfidence
        self.languageSelection = languageSelection
        self.customLanguage = customLanguage
        self.detectedLanguageName = detectedLanguageName
        self.intent = intent
        self.uniqueThought = uniqueThought
        self.personaProfile = personaProfile
        self.styleExamples = styleExamples
        self.additionalPromptContext = additionalPromptContext
        self.reworkTarget = reworkTarget
        self.retryFeedback = retryFeedback
    }

    public var resolvedLanguageLabel: String {
        switch languageSelection {
        case .sameAsPost:
            if let detected = detectedLanguageName, !detected.isEmpty {
                return detected
            }
            return "English"
        case .english:
            return "English"
        case .spanish:
            return "Spanish"
        case .custom:
            return customLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? personaProfile.defaultLanguage
                : customLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

public struct GeneratedCandidate: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var text: String
    public var lengthCategory: CommentLengthCategory

    public init(
        id: String,
        text: String,
        lengthCategory: CommentLengthCategory
    ) {
        self.id = id
        self.text = text
        self.lengthCategory = lengthCategory
    }
}

public enum AppError: LocalizedError {
    case unsupportedFrontmostApplication(String)
    case noEligibleWindow
    case screenRecordingPermissionDenied
    case invalidPersonaFile(String)
    case invalidAPIKeyFile(String)
    case missingPersona
    case missingAPIKey
    case missingReadingSelection
    case readingSelectionOutsideWindow
    case emptyPostText
    case generationFailed(String)
    case networkError(String)
    case lowConfidencePostDetection
    case cropFailed
    case missingLocalProvider(String)
    case unsupportedEnvironment(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFrontmostApplication(let name):
            return "\(name) is not a supported browser. Open LinkedIn in Brave, Safari, Chrome, or Arc."
        case .noEligibleWindow:
            return "No visible browser window could be captured."
        case .screenRecordingPermissionDenied:
            return "Screen Recording permission is required to scan the visible LinkedIn feed."
        case .invalidPersonaFile(let message):
            return "The persona file is invalid: \(message)"
        case .invalidAPIKeyFile(let message):
            return "The API key file is invalid: \(message)"
        case .missingPersona:
            return "Import a persona Markdown profile before generating comments."
        case .missingAPIKey:
            return "Save an OpenAI API key in Settings before generating comments."
        case .missingReadingSelection:
            return "Set a reading selection before scanning."
        case .readingSelectionOutsideWindow:
            return "The reading selection does not overlap the captured browser window."
        case .emptyPostText:
            return "There is no extracted post text to generate from."
        case .generationFailed(let message):
            return "Comment generation failed: \(message)"
        case .networkError(let message):
            return "The OpenAI request failed: \(message)"
        case .lowConfidencePostDetection:
            return "A dominant post could not be identified confidently. Use Manual Crop or edit the extracted text."
        case .cropFailed:
            return "The selected crop could not be processed."
        case .missingLocalProvider(let message):
            return message
        case .unsupportedEnvironment(let message):
            return message
        }
    }
}
