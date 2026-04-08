import SwiftUI

public struct CompanionPanelView: View {
    @ObservedObject private var model: AppModel
    @State private var isPostEditorExpanded = false
    @State private var showCopiedToast = false
    @State private var isHoveringTab = false

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            if model.isOverlayExpanded {
                expandedSidebar
                    .transition(.move(edge: model.overlayEdge == .right ? .trailing : .leading).combined(with: .opacity))
            } else {
                edgeStrip
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.2), value: model.isOverlayExpanded)
        .sheet(isPresented: $model.isCropSheetPresented) {
            if let image = model.scanResult?.capturedWindow.image {
                CropSelectionView(image: image) { croppedImage in
                    model.applyManualCrop(croppedImage)
                }
            }
        }
        .onChange(of: model.editablePostText) { _, newValue in
            if !newValue.isEmpty && isPostEditorExpanded {
                isPostEditorExpanded = false
            }
        }
    }

    private var alignment: Alignment {
        model.overlayEdge == .right ? .trailing : .leading
    }

    // MARK: - Collapsed: Only the pill tab is clickable

    private var edgeStrip: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Button {
                model.toggleOverlayExpanded()
            } label: {
                Image(systemName: toggleChevron)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 56)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.45, green: 0.62, blue: 0.98),
                                Color(red: 0.28, green: 0.42, blue: 0.88)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: model.overlayEdge == .right ? 10 : 0,
                            bottomLeadingRadius: model.overlayEdge == .right ? 10 : 0,
                            bottomTrailingRadius: model.overlayEdge == .right ? 0 : 10,
                            topTrailingRadius: model.overlayEdge == .right ? 0 : 10
                        )
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: model.overlayEdge == .right ? -2 : 2, y: 0)
                    .scaleEffect(isHoveringTab ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isHoveringTab)
                    .contentShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: model.overlayEdge == .right ? 10 : 0,
                            bottomLeadingRadius: model.overlayEdge == .right ? 10 : 0,
                            bottomTrailingRadius: model.overlayEdge == .right ? 0 : 10,
                            topTrailingRadius: model.overlayEdge == .right ? 0 : 10
                        )
                    )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringTab = hovering
            }
            Spacer(minLength: 0)
        }
        .frame(width: 28)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Expanded Sidebar

    private var sidebarCornerShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: model.overlayEdge == .right ? 16 : 0,
            bottomLeadingRadius: model.overlayEdge == .right ? 16 : 0,
            bottomTrailingRadius: model.overlayEdge == .right ? 0 : 16,
            topTrailingRadius: model.overlayEdge == .right ? 0 : 16
        )
    }

    private var expandedSidebar: some View {
        HStack(spacing: 0) {
            if model.overlayEdge == .right {
                closeFlap
            }

            // Main sidebar content
            VStack(spacing: 0) {
                compactHeader
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                VStack(spacing: 8) {
                    actionRow
                    controlsRow
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

                Divider()
                    .padding(.horizontal, 14)

                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        statusBanners
                        extractedTextSection
                        perspectiveField
                        candidateSection
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .frame(width: 340)
            .frame(maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.92, green: 0.94, blue: 0.99)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(sidebarCornerShape)
            .overlay(
                sidebarCornerShape
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 14, x: model.overlayEdge == .right ? -4 : 4, y: 0)

            if model.overlayEdge == .left {
                closeFlap
            }
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                Text("Copied!")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(red: 0.12, green: 0.50, blue: 0.25), in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
    }

    private var closeFlap: some View {
        Button {
            model.toggleOverlayExpanded()
        } label: {
            Image(systemName: toggleChevron)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 48)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.45, green: 0.62, blue: 0.98), Color(red: 0.28, green: 0.42, blue: 0.88)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: model.overlayEdge == .right ? 8 : 0,
                        bottomLeadingRadius: model.overlayEdge == .right ? 8 : 0,
                        bottomTrailingRadius: model.overlayEdge == .right ? 0 : 8,
                        topTrailingRadius: model.overlayEdge == .right ? 0 : 8
                    )
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
    }

    // MARK: - Header

    private var compactHeader: some View {
        HStack(spacing: 10) {
            Text("LKD Comments")
                .font(.headline)

            Spacer()

            Button {
                model.toggleReadingMode()
            } label: {
                Image(systemName: model.isReadingModeActive ? "viewfinder.rectangular" : "viewfinder.circle")
                    .font(.subheadline)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(model.isReadingModeActive ? Color(red: 0.35, green: 0.57, blue: 0.98) : .secondary)
            }
            .buttonStyle(.plain)
            .help(model.isReadingModeActive ? "Exit Reading Mode" : "Reading Mode")

            Button {
                model.openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
                    .font(.subheadline)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Action Row (Scan + Generate)

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button {
                model.triggerScan()
            } label: {
                HStack(spacing: 5) {
                    if model.isScanning {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: model.isReadingModeActive ? "selection.pin.in.out" : "viewfinder")
                    }
                    Text(model.isScanning ? "Scanning…" : "Scan")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .background(Color(red: 0.93, green: 0.96, blue: 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.35, green: 0.57, blue: 0.98).opacity(0.2), lineWidth: 1)
            )
            .disabled(model.isScanning)

            if model.isGenerating {
                Button {
                    model.cancelGeneration()
                } label: {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.mini).tint(.white)
                        Text("Cancel")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .background(Color.red.opacity(0.85))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Button {
                    model.triggerGenerate()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: model.generatedCandidates.isEmpty ? "sparkles" : "arrow.clockwise")
                        Text(model.generatedCandidates.isEmpty ? "Generate" : "Generate New Set")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.40, green: 0.58, blue: 0.98), Color(red: 0.22, green: 0.36, blue: 0.85)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!model.canGenerate || model.isScanning)
            }
        }
    }

    // MARK: - Controls Row

    private var controlsRow: some View {
        HStack(spacing: 8) {
            Picker("Intent", selection: $model.selectedIntent) {
                ForEach(CommentIntent.allCases) { intent in
                    Text(intent.displayName).tag(intent)
                }
            }
            .pickerStyle(.menu)
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Language", selection: $model.selectedLanguage) {
                ForEach(CommentLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.menu)
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)

            if model.selectedLanguage == .custom {
                TextField("Language", text: $model.customLanguageInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .frame(maxWidth: 80)
            }
        }
    }

    // MARK: - Status Banners

    private var statusBanners: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let error = model.errorMessage {
                labelPill(text: error, tint: .red, background: Color(red: 1.0, green: 0.93, blue: 0.93))
            }

            if let status = model.statusMessage {
                labelPill(text: status, tint: Color(red: 0.12, green: 0.43, blue: 0.25), background: Color(red: 0.90, green: 0.96, blue: 0.91))
            }

            if let readinessMessage = model.generationReadinessMessage {
                HStack(spacing: 6) {
                    Text(readinessMessage)
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.48, green: 0.28, blue: 0.07))
                    Button("Settings") { model.openSettingsWindow() }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(red: 0.35, green: 0.57, blue: 0.98))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.99, green: 0.96, blue: 0.87))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Post Text

    private var extractedTextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Post text")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(isPostEditorExpanded ? "Fold" : "Expand") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isPostEditorExpanded.toggle()
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(Color(red: 0.35, green: 0.57, blue: 0.98))
            }

            if isPostEditorExpanded {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $model.editablePostText)
                        .font(.callout)
                        .frame(minHeight: 80, maxHeight: 150)
                        .scrollContentBackground(.hidden)

                    if model.editablePostText.isEmpty {
                        Text("Paste or type a LinkedIn post here…")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else if !model.editablePostText.isEmpty {
                Text(model.editablePostText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else {
                Button {
                    isPostEditorExpanded = true
                } label: {
                    Text("Paste or scan a post to get started")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.white.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Perspective

    private var perspectiveField: some View {
        TextField("Add your perspective…", text: $model.uniqueThought, axis: .vertical)
            .font(.callout)
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...2)
    }

    // MARK: - Candidates

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.generatedCandidates.isEmpty {
                Text("Generated comments will appear here.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.white.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(model.generatedCandidates) { candidate in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 6) {
                            Text(candidate.lengthCategory.rawValue.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                model.copy(candidate: candidate)
                                withAnimation(.easeInOut(duration: 0.2)) { showCopiedToast = true }
                                Task {
                                    try? await Task.sleep(for: .seconds(1.2))
                                    withAnimation(.easeInOut(duration: 0.3)) { showCopiedToast = false }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(red: 0.35, green: 0.57, blue: 0.98))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.93, green: 0.96, blue: 1.0))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                model.regenerate(candidate: candidate)
                            } label: {
                                HStack(spacing: 3) {
                                    if model.regeneratingCandidateID == candidate.id {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text("Regen")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(red: 0.55, green: 0.32, blue: 0.85))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.96, green: 0.93, blue: 1.0))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(!model.canRegenerate || model.regeneratingCandidateID == candidate.id)
                        }

                        Text(candidate.text)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Helpers

    private func labelPill(text: String, tint: Color, background: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var toggleChevron: String {
        switch (model.overlayEdge, model.isOverlayExpanded) {
        case (.right, true):
            return "chevron.right"
        case (.right, false):
            return "chevron.left"
        case (.left, true):
            return "chevron.left"
        case (.left, false):
            return "chevron.right"
        }
    }
}
