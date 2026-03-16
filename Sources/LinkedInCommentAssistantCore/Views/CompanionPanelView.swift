import SwiftUI

public struct CompanionPanelView: View {
    @ObservedObject private var model: AppModel
    @State private var isPostEditorExpanded = true

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 10) {
                if model.overlayEdge == .left {
                    edgeHandle
                }

                if model.isOverlayExpanded {
                    expandedCard(availableHeight: proxy.size.height - 16)
                        .transition(.move(edge: model.overlayEdge == .right ? .trailing : .leading).combined(with: .opacity))
                }

                if model.overlayEdge == .right {
                    edgeHandle
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .background(Color.clear)
            .animation(.spring(response: 0.24, dampingFraction: 0.92), value: model.isOverlayExpanded)
            .sheet(isPresented: $model.isCropSheetPresented) {
                if let image = model.scanResult?.capturedWindow.image {
                    CropSelectionView(image: image) { croppedImage in
                        model.applyManualCrop(croppedImage)
                    }
                }
            }
        }
    }

    private var alignment: Alignment {
        model.overlayEdge == .right ? .trailing : .leading
    }

    private var edgeHandle: some View {
        VStack(spacing: 12) {
            Button {
                model.toggleOverlayExpanded()
            } label: {
                Image(systemName: toggleChevron)
                    .font(.headline.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Capsule()
                .fill(Color.white.opacity(0.45))
                .frame(width: 18, height: 4)

            Button {
                model.triggerScan()
            } label: {
                Image(systemName: "viewfinder")
                    .font(.title3.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            if !model.generatedCandidates.isEmpty {
                Button {
                    model.copyBestCandidate()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.title3.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Button {
                let nextEdge: OverlayEdge = model.overlayEdge == .right ? .left : .right
                model.setOverlayEdge(nextEdge)
            } label: {
                Image(systemName: "rectangle.lefthalf.inset.filled.arrow.left")
                    .rotationEffect(.degrees(model.overlayEdge == .right ? 180 : 0))
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 14)
        .frame(width: 58)
        .frame(maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.35, green: 0.57, blue: 0.98), Color(red: 0.13, green: 0.29, blue: 0.63)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .gesture(handleDragGesture)
    }

    private func expandedCard(availableHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                header
                statusSection
            }

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    quickControls
                    extractedTextSection
                    candidateSection
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            Divider()
                .padding(.vertical, 12)

            actionButtons
        }
        .padding(18)
        .frame(width: 342, height: max(availableHeight, 540), alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.99, blue: 1.0), Color(red: 0.92, green: 0.95, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 10)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LinkedIn Assistant")
                    .font(.title3.weight(.semibold))
                Text("Scan the visible feed, tune the comment, then copy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                model.openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let status = model.statusMessage {
                labelPill(text: status, tint: Color(red: 0.12, green: 0.43, blue: 0.25), background: Color(red: 0.89, green: 0.96, blue: 0.90))
            }

            if let error = model.errorMessage {
                labelPill(text: error, tint: .red, background: Color(red: 1.0, green: 0.92, blue: 0.92))
            }

            if !model.currentWarnings.isEmpty {
                ForEach(model.currentWarnings, id: \.self) { warning in
                    labelPill(
                        text: warning,
                        tint: Color(red: 0.48, green: 0.28, blue: 0.07),
                        background: Color(red: 0.99, green: 0.95, blue: 0.85)
                    )
                }
            }
        }
    }

    private var quickControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            primaryScanButton

            Button {
                model.toggleReadingMode()
            } label: {
                HStack {
                    Image(systemName: model.isReadingModeActive ? "xmark.rectangle.fill" : "viewfinder.circle")
                    Text(model.isReadingModeActive ? "Exit Reading Mode" : "Reading Mode")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if model.isReadingModeActive {
                Text("Reading mode is active. Scroll normally, position the box over the post, then scan only that box.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                scoreBadge(title: "Provider", value: model.activeProviderDisplayName)

                if let scanResult = model.scanResult {
                    scoreBadge(title: "OCR", value: percentage(scanResult.overallConfidence))
                    scoreBadge(title: "Feed", value: percentage(scanResult.linkedInConfidence))
                    scoreBadge(title: "Source", value: scanResult.capturedWindow.appName)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Comment style")
                    .font(.subheadline.weight(.semibold))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CommentIntent.allCases) { intent in
                            Button(intent.displayName) {
                                model.selectedIntent = intent
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(model.selectedIntent == intent ? Color(red: 0.35, green: 0.57, blue: 0.98) : Color.white.opacity(0.92))
                            )
                            .foregroundStyle(model.selectedIntent == intent ? .white : .primary)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Picker("Language", selection: $model.selectedLanguage) {
                    ForEach(CommentLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if model.selectedLanguage == .custom {
                TextField("Custom language", text: $model.customLanguageInput)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Add perspective")
                    .font(.subheadline.weight(.semibold))

                TextField("I.e., mention what stood out to you…", text: $model.uniqueThought, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        }
    }

    private var extractedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Detected post")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(isPostEditorExpanded ? "Fold" : "Edit") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isPostEditorExpanded.toggle()
                    }
                }
                .buttonStyle(.plain)
            }

            if isPostEditorExpanded {
                TextEditor(text: $model.editablePostText)
                    .font(.callout)
                    .frame(minHeight: 132, maxHeight: 164)
                    .padding(10)
                    .background(Color.white.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                Text(model.editablePostText.isEmpty ? "No post text yet. Run Scan." : model.editablePostText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if let readinessMessage = model.generationReadinessMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(readinessMessage)
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.48, green: 0.28, blue: 0.07))
                    Button("Open Settings") {
                        model.openSettingsWindow()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(red: 0.99, green: 0.95, blue: 0.85))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }

            Button {
                model.triggerGenerate()
            } label: {
                HStack {
                    Image(systemName: model.generatedCandidates.isEmpty ? "sparkles" : "arrow.clockwise")
                    Text(model.generatedCandidates.isEmpty ? "Generate Comments" : "Regenerate Comments")
                }
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.45, green: 0.61, blue: 0.99), Color(red: 0.22, green: 0.34, blue: 0.82)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .disabled(!model.canGenerate || model.isScanning)

            HStack(spacing: 10) {
                Button("Copy Best") {
                    model.copyBestCandidate()
                }
                .disabled(model.generatedCandidates.isEmpty)

                Button("Manual Crop") {
                    model.presentCropSheet()
                }
                .disabled(model.scanResult == nil)
            }
            .buttonStyle(.bordered)
        }
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Candidates")
                .font(.subheadline.weight(.semibold))

            if model.generatedCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No generated comments yet.")
                        .font(.callout.weight(.medium))
                    Text("Use Scan while LinkedIn is visible in Brave, Safari, Chrome, or Arc, then generate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(model.generatedCandidates) { candidate in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(candidate.lengthCategory.rawValue.capitalized)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Copy") {
                                    model.copy(candidate: candidate)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(candidate.text)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.94))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
        }
    }

    private var primaryScanButton: some View {
        Button {
            model.triggerScan()
        } label: {
            HStack {
                Image(systemName: model.isScanning ? "hourglass" : (model.isReadingModeActive ? "selection.pin.in.out" : "viewfinder"))
                Text(
                    model.isScanning
                        ? "Scanning LinkedIn…"
                        : (model.isReadingModeActive ? "Scan Selection" : "Scan LinkedIn Feed")
                )
            }
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 0.35, green: 0.57, blue: 0.98).opacity(0.35), lineWidth: 1)
        )
    }

    private func labelPill(text: String, tint: Color, background: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func scoreBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var handleDragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onEnded { value in
                model.moveOverlay(by: value.translation.height)
            }
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

    private func percentage(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
