import Carbon
import SwiftUI
import UniformTypeIdentifiers

public struct SettingsView: View {
    @ObservedObject private var model: AppModel
    @State private var isPersonaFileImporterPresented = false
    @State private var isAPIKeyFileImporterPresented = false
    @State private var apiKeyDraft = ""

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                onboardingSection
                personaSection
                styleCorpusSection
                providerSection
                defaultsSection
                privacySection
                hotKeySection
            }
            .padding(24)
        }
        .frame(minWidth: 860, minHeight: 720)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.97, blue: 0.99), Color(red: 0.89, green: 0.93, blue: 0.97)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .fileImporter(
            isPresented: $isPersonaFileImporterPresented,
            allowedContentTypes: supportedPersonaContentTypes
        ) { result in
            guard case .success(let url) = result else { return }
            model.importPersona(from: url)
        }
        .fileImporter(
            isPresented: $isAPIKeyFileImporterPresented,
            allowedContentTypes: supportedAPIKeyContentTypes
        ) { result in
            guard case .success(let url) = result else { return }
            model.importAPIKey(from: url)
        }
    }

    private var supportedPersonaContentTypes: [UTType] {
        let markdownType = UTType(filenameExtension: "md") ?? .plainText
        return [.plainText, .text, markdownType]
    }

    private var supportedAPIKeyContentTypes: [UTType] {
        let envType = UTType(filenameExtension: "env") ?? .plainText
        return [.plainText, .text, envType]
    }

    private var onboardingSection: some View {
        sectionCard(title: "Onboarding") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Configure Screen Recording, choose a provider, optionally import a persona Markdown file, and add style/context notes. Generated comments are not stored.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    statusPill(
                        title: "Screen Recording",
                        isComplete: model.permissionState == .granted
                    )
                    statusPill(
                        title: "Persona",
                        isComplete: model.personaProfile != nil
                    )
                    statusPill(
                        title: model.settings.provider.kind == .openAI ? "OpenAI Key" : "Local Provider",
                        isComplete: model.isProviderReady
                    )
                }

                HStack(spacing: 12) {
                    Button("Grant Screen Recording Access") {
                        model.requestScreenRecordingAccess()
                    }

                    Button("Refresh Permission Status") {
                        model.refreshPermissionState()
                    }
                    .buttonStyle(.bordered)

                    Button("Open System Settings") {
                        model.openScreenRecordingPreferences()
                    }
                    .buttonStyle(.bordered)

                    Button("Relaunch App") {
                        model.relaunchApplication()
                    }
                    .buttonStyle(.bordered)
                }

                Text("After allowing Screen Recording in macOS, return to the app and press Refresh. If macOS still shows it as denied, use Relaunch App once.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                statusAndErrorMessages
            }
        }
    }

    private var personaSection: some View {
        sectionCard(title: "Persona Profile") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Import Persona Markdown") {
                        isPersonaFileImporterPresented = true
                    }

                    Button("Use Built-In Persona") {
                        model.useBuiltInPersona()
                    }
                    .buttonStyle(.bordered)
                }

                if let persona = model.personaProfile {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(persona.name)
                            .font(.title3.weight(.semibold))
                        Text(model.isUsingImportedPersona ? "Imported Markdown persona" : "Built-in fallback persona")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Default language: \(persona.defaultLanguage) • Default intent: \(persona.defaultIntent.displayName) • Max sentences: \(persona.maxCommentSentences)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Voice: \(persona.voice)")
                            .font(.subheadline)
                        Text("Tone: \(persona.tone)")
                            .font(.subheadline)
                    }
                } else {
                    Text("Expected format: YAML front matter with `name`, `default_language`, `default_intent`, `max_comment_sentences`, followed by `## Voice`, `## Tone`, `## Do`, and `## Avoid` sections.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Imported persona files are copied into the app’s Application Support folder, so the app does not depend on the original file staying readable later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var styleCorpusSection: some View {
        sectionCard(title: "Style Examples And Prompt Context") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste prior comments separated by blank lines. These stay local and are used only as retrieval examples at generation time.")
                    .foregroundStyle(.secondary)

                TextEditor(text: settingsBinding(\.styleCorpusRawText))
                    .font(.body.monospaced())
                    .frame(minHeight: 220)
                    .padding(10)
                    .background(.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text("\(model.styleCorpus.count) unique examples ready for retrieval")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Text("Global prompt/context")
                    .font(.headline)

                Text("Use this for stable instructions that should be included on every generation, such as audience, style notes, banned phrases, or recurring context.")
                    .foregroundStyle(.secondary)

                TextEditor(text: settingsBinding(\.additionalPromptContext))
                    .font(.body.monospaced())
                    .frame(minHeight: 140)
                    .padding(10)
                    .background(.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var providerSection: some View {
        sectionCard(title: "LLM Provider") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Provider", selection: settingsBinding(\.provider.kind)) {
                    ForEach(ProviderKind.allCases) { providerKind in
                        Text(providerKind.displayName).tag(providerKind)
                    }
                }
                .pickerStyle(.segmented)

                if model.settings.provider.kind == .openAI {
                    TextField("OpenAI model", text: settingsBinding(\.provider.openAIModel))
                        .textFieldStyle(.roundedBorder)

                    TextField("OpenAI API endpoint", text: settingsBinding(\.provider.openAIBaseURL))
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 12) {
                        SecureField(model.hasStoredAPIKey ? "Stored in Keychain" : "OpenAI API key", text: $apiKeyDraft)
                            .textFieldStyle(.roundedBorder)

                        Button("Save Key") {
                            guard !apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            model.saveAPIKey(apiKeyDraft)
                            apiKeyDraft = ""
                        }

                        if model.hasStoredAPIKey {
                            Button("Remove Key") {
                                model.removeAPIKey()
                            }
                            .buttonStyle(.bordered)
                        }

                        Button("Import .env / Key File") {
                            isAPIKeyFileImporterPresented = true
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("The API key is saved to macOS Keychain, not stored in source code or in the app settings file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("Ollama model", text: settingsBinding(\.provider.ollamaModel))
                        .textFieldStyle(.roundedBorder)

                    TextField("Ollama endpoint", text: settingsBinding(\.provider.ollamaBaseURL))
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        Button("Check Local Provider") {
                            model.refreshProviderHealth()
                        }
                        .buttonStyle(.borderedProminent)

                        providerHealthBadge
                    }

                    Text(model.localProviderHealthMessage)
                        .font(.caption)
                        .foregroundStyle(providerHealthColor)

                    Text("Expected local server: `ollama serve` or `brew services start ollama`, usually at `http://127.0.0.1:11434/api/generate`.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("If your Mac becomes unstable with larger models, switch to a lighter Ollama model (for example, 7B or 3B).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var providerHealthBadge: some View {
        let title: String
        switch model.localProviderHealth {
        case .ready:
            title = "Ready"
        case .checking:
            title = "Checking"
        case .unknown:
            title = "Unknown"
        case .unavailable:
            title = "Offline"
        case .modelMissing:
            title = "Model Missing"
        case .invalidEndpoint:
            title = "Invalid URL"
        case .resourceRisk:
            title = "Too Large"
        }

        return Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(providerHealthColor.opacity(0.18))
            .foregroundStyle(providerHealthColor)
            .clipShape(Capsule())
    }

    private var providerHealthColor: Color {
        switch model.localProviderHealth {
        case .ready:
            return Color(red: 0.08, green: 0.50, blue: 0.22)
        case .checking:
            return Color(red: 0.12, green: 0.42, blue: 0.82)
        case .unknown:
            return .secondary
        case .unavailable, .modelMissing, .invalidEndpoint, .resourceRisk:
            return .red
        }
    }

    private var defaultsSection: some View {
        sectionCard(title: "Defaults") {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Default intent", selection: settingsBinding(\.defaultIntent)) {
                    ForEach(CommentIntent.allCases) { intent in
                        Text(intent.displayName).tag(intent)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Default language", selection: settingsBinding(\.defaultLanguage)) {
                    ForEach(CommentLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)

                if model.settings.defaultLanguage == .custom {
                    TextField("Custom language", text: settingsBinding(\.customLanguageName))
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Collapse the overlay after copying a candidate", isOn: settingsBinding(\.collapseAfterCopy))

                Picker("Overlay side", selection: settingsBinding(\.overlayEdge)) {
                    ForEach(OverlayEdge.allCases) { edge in
                        Text(edge.displayName).tag(edge)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var privacySection: some View {
        sectionCard(title: "Privacy") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable debug logging", isOn: settingsBinding(\.debugLoggingEnabled))

                Text("Screenshots and generated comments stay in memory for the current session. Only OCR text is sent to the configured LLM provider.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Show Overlay") {
                        model.presentCurrentCompanion()
                    }

                    Button("Trigger Scan Now") {
                        model.triggerScan()
                    }
                }
            }
        }
    }

    private var hotKeySection: some View {
        sectionCard(title: "Global Hotkey") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Picker("Key", selection: hotKeyKeyBinding) {
                        ForEach(HotKeyCatalog.commonKeys) { option in
                            Text(option.label).tag(option.keyCode)
                        }
                    }
                    .frame(maxWidth: 180)

                    Toggle("Control", isOn: modifierBinding(UInt32(controlKey)))
                    Toggle("Option", isOn: modifierBinding(UInt32(optionKey)))
                    Toggle("Command", isOn: modifierBinding(UInt32(cmdKey)))
                    Toggle("Shift", isOn: modifierBinding(UInt32(shiftKey)))
                }

                Text("Current hotkey: \(HotKeyCatalog.label(for: model.settings.hotKey))")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusAndErrorMessages: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let status = model.statusMessage {
                Text(status)
                    .font(.callout)
                    .foregroundStyle(Color(red: 0.10, green: 0.41, blue: 0.23))
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    private func statusPill(title: String, isComplete: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle.dashed")
            Text(title)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(isComplete ? Color(red: 0.11, green: 0.44, blue: 0.25) : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 999)
                .fill(isComplete ? Color(red: 0.86, green: 0.95, blue: 0.88) : Color.white.opacity(0.7))
        )
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func settingsBinding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in
                var copy = model.settings
                copy[keyPath: keyPath] = newValue
                model.settings = copy
            }
        )
    }

    private var hotKeyKeyBinding: Binding<UInt32> {
        Binding(
            get: { model.settings.hotKey.keyCode },
            set: { newValue in
                var copy = model.settings
                copy.hotKey.keyCode = newValue
                model.settings = copy
            }
        )
    }

    private func modifierBinding(_ flag: UInt32) -> Binding<Bool> {
        Binding(
            get: { model.settings.hotKey.modifiers & flag != 0 },
            set: { isEnabled in
                var copy = model.settings
                if isEnabled {
                    copy.hotKey.modifiers |= flag
                } else {
                    copy.hotKey.modifiers &= ~flag
                }
                model.settings = copy
            }
        )
    }
}
