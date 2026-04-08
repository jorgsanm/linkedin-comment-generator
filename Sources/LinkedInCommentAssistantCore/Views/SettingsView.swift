import Carbon
import SwiftUI
import UniformTypeIdentifiers

public struct SettingsView: View {
    @ObservedObject private var model: AppModel
    @State private var isPersonaFileImporterPresented = false
    @State private var isContextFileImporterPresented = false
    @State private var isAPIKeyFileImporterPresented = false
    @State private var apiKeyDraft = ""
    @State private var useCustomOpenAIModel = false
    @State private var useCustomOllamaModel = false

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                onboardingSection
                styleAndGuidelinesSection
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
            allowedContentTypes: supportedTextContentTypes
        ) { result in
            guard case .success(let url) = result else { return }
            model.importPersona(from: url)
        }
        .fileImporter(
            isPresented: $isContextFileImporterPresented,
            allowedContentTypes: supportedTextContentTypes
        ) { result in
            guard case .success(let url) = result else { return }
            model.importContextFile(from: url)
        }
        .fileImporter(
            isPresented: $isAPIKeyFileImporterPresented,
            allowedContentTypes: supportedTextContentTypes
        ) { result in
            guard case .success(let url) = result else { return }
            model.importAPIKey(from: url)
        }
        .onAppear {
            useCustomOpenAIModel = !ProviderSettings.openAIModelPresets.contains(model.settings.provider.openAIModel)
            useCustomOllamaModel = !model.availableOllamaModels.contains(model.settings.provider.ollamaModel)
        }
    }

    private var supportedTextContentTypes: [UTType] {
        let mdType = UTType(filenameExtension: "md") ?? .plainText
        let envType = UTType(filenameExtension: "env") ?? .plainText
        return [.plainText, .text, mdType, envType]
    }

    // MARK: - Onboarding

    private var onboardingSection: some View {
        sectionCard(title: "Setup") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    statusPill(title: "Screen Recording", isComplete: model.permissionState == .granted)
                    statusPill(
                        title: model.settings.provider.kind == .openAI ? "OpenAI Key" : "Local Provider",
                        isComplete: model.isProviderReady
                    )
                }

                HStack(spacing: 12) {
                    Button("Grant Screen Recording") {
                        model.requestScreenRecordingAccess()
                    }

                    Button("Refresh") {
                        model.refreshPermissionState()
                    }
                    .buttonStyle(.bordered)

                    Button("System Settings") {
                        model.openScreenRecordingPreferences()
                    }
                    .buttonStyle(.bordered)

                    Button("Relaunch") {
                        model.relaunchApplication()
                    }
                    .buttonStyle(.bordered)
                }

                statusAndErrorMessages
            }
        }
    }

    // MARK: - Style & Guidelines (merged persona + corpus + prompt)

    private var styleAndGuidelinesSection: some View {
        sectionCard(title: "Style & Guidelines") {
            VStack(alignment: .leading, spacing: 12) {
                // Persona subsection
                DisclosureGroup("Persona Profile") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Button("Import Persona File") {
                                isPersonaFileImporterPresented = true
                            }
                            .buttonStyle(.bordered)

                            Button("Use Built-In") {
                                model.useBuiltInPersona()
                            }
                            .buttonStyle(.bordered)
                        }

                        if let persona = model.personaProfile {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(persona.name) — \(model.isUsingImportedPersona ? "Imported" : "Built-in")")
                                    .font(.subheadline.weight(.medium))
                                Text("Voice: \(persona.voice)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Tone: \(persona.tone)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.subheadline.weight(.medium))

                Divider()

                // Style examples
                Text("Style examples")
                    .font(.subheadline.weight(.medium))
                Text("Paste prior comments separated by blank lines. Used as retrieval examples.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: settingsBinding(\.styleCorpusRawText))
                    .font(.body.monospaced())
                    .frame(height: 300)
                    .padding(10)
                    .background(.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("\(model.styleCorpus.count) unique examples ready for retrieval")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                // Global prompt/context
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Global prompt / context")
                            .font(.subheadline.weight(.medium))
                        Text("Stable instructions for every generation: audience, style, banned phrases, or any context.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Import File") {
                        isContextFileImporterPresented = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                TextEditor(text: settingsBinding(\.additionalPromptContext))
                    .font(.body.monospaced())
                    .frame(height: 220)
                    .padding(10)
                    .background(.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Provider

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
                    openAIProviderSection
                } else {
                    ollamaProviderSection
                }
            }
        }
    }

    private var openAIProviderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Model picker
            HStack(spacing: 8) {
                Picker("Model", selection: openAIModelPickerBinding) {
                    ForEach(ProviderSettings.openAIModelPresets, id: \.self) { model in
                        Text(model).tag(model)
                    }
                    Text("Custom…").tag("__custom__")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)

                if useCustomOpenAIModel {
                    TextField("Model name", text: settingsBinding(\.provider.openAIModel))
                        .textFieldStyle(.roundedBorder)
                }
            }

            TextField("API endpoint", text: settingsBinding(\.provider.openAIBaseURL))
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
                    Button("Remove Key") { model.removeAPIKey() }
                        .buttonStyle(.bordered)
                }

                Button("Import Key File") { isAPIKeyFileImporterPresented = true }
                    .buttonStyle(.bordered)
            }

            Text("API key is saved to macOS Keychain, not stored in source code or settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var ollamaProviderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Model picker
            HStack(spacing: 8) {
                if model.availableOllamaModels.isEmpty {
                    TextField("Ollama model", text: settingsBinding(\.provider.ollamaModel))
                        .textFieldStyle(.roundedBorder)
                } else {
                    Picker("Model", selection: ollamaModelPickerBinding) {
                        ForEach(model.availableOllamaModels, id: \.self) { modelName in
                            Text(modelName).tag(modelName)
                        }
                        Text("Custom…").tag("__custom__")
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)

                    if useCustomOllamaModel {
                        TextField("Model name", text: settingsBinding(\.provider.ollamaModel))
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Button("Refresh") { model.refreshProviderHealth() }
                    .buttonStyle(.bordered)
            }

            TextField("Ollama endpoint", text: settingsBinding(\.provider.ollamaBaseURL))
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button("Check Provider") { model.refreshProviderHealth() }
                    .buttonStyle(.borderedProminent)
                providerHealthBadge
            }

            Text(model.localProviderHealthMessage)
                .font(.caption)
                .foregroundStyle(providerHealthColor)
        }
    }

    // Model picker bindings

    private var openAIModelPickerBinding: Binding<String> {
        Binding(
            get: {
                let current = model.settings.provider.openAIModel
                if ProviderSettings.openAIModelPresets.contains(current) {
                    return current
                }
                return "__custom__"
            },
            set: { newValue in
                if newValue == "__custom__" {
                    useCustomOpenAIModel = true
                } else {
                    useCustomOpenAIModel = false
                    var copy = model.settings
                    copy.provider.openAIModel = newValue
                    model.settings = copy
                }
            }
        )
    }

    private var ollamaModelPickerBinding: Binding<String> {
        Binding(
            get: {
                let current = model.settings.provider.ollamaModel
                if model.availableOllamaModels.contains(current) {
                    return current
                }
                return "__custom__"
            },
            set: { newValue in
                if newValue == "__custom__" {
                    useCustomOllamaModel = true
                } else {
                    useCustomOllamaModel = false
                    var copy = model.settings
                    copy.provider.ollamaModel = newValue
                    model.settings = copy
                }
            }
        )
    }

    private var providerHealthBadge: some View {
        let title: String
        switch model.localProviderHealth {
        case .ready: title = "Ready"
        case .checking: title = "Checking"
        case .unknown: title = "Unknown"
        case .unavailable: title = "Offline"
        case .modelMissing: title = "Model Missing"
        case .invalidEndpoint: title = "Invalid URL"
        case .resourceRisk: title = "Too Large"
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
        case .ready: return Color(red: 0.08, green: 0.50, blue: 0.22)
        case .checking: return Color(red: 0.12, green: 0.42, blue: 0.82)
        case .unknown: return .secondary
        case .unavailable, .modelMissing, .invalidEndpoint, .resourceRisk: return .red
        }
    }

    // MARK: - Defaults

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

                Picker("Overlay side", selection: settingsBinding(\.overlayEdge)) {
                    ForEach(OverlayEdge.allCases) { edge in
                        Text(edge.displayName).tag(edge)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        sectionCard(title: "Privacy") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable debug logging", isOn: settingsBinding(\.debugLoggingEnabled))

                Text("Screenshots and generated comments stay in memory for the current session. Only OCR text is sent to the configured LLM provider.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Show Overlay") { model.presentCurrentCompanion() }
                    Button("Trigger Scan Now") { model.triggerScan() }
                }
            }
        }
    }

    // MARK: - Hotkey

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

    // MARK: - Helpers

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
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.weight(.semibold))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
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
