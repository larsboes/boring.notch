import SwiftUI

/// Expanded panel for teleprompter — editing, setup, and configuration only.
/// When play is pressed, the notch closes and the compact TeleprompterClosedView takes over.
struct TeleprompterExpandedView: View {
    @Bindable var state: TeleprompterState
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.settings) var settings
    @Environment(BoringViewModel.self) var vm

    @State private var isAIProcessing: Bool = false
    @State private var aiError: String?

    var body: some View {
        VStack(spacing: 10) {
            // MARK: - Text Input Area
            ZStack(alignment: .topLeading) {
                TextEditor(text: $state.text)
                    .font(.system(size: 14, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .frame(height: 120)

                if state.text.isEmpty {
                    Text("Paste or type your script…")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 16)
                        .padding(.leading, 13)
                        .allowsHitTesting(false)
                }
            }

            // MARK: - AI Actions
            if settings.isAIEnabled && !state.text.isEmpty {
                aiActionBar
            }

            // MARK: - Error Banner
            if let error = aiError {
                errorBanner(error)
            }

            // MARK: - Controls
            controlBar
        }
        .padding(12)
        .frame(width: 340)
        .onAppear {
            // Notch opened — stop scrolling so user can edit
            state.isScrolling = false
        }
        .overlay {
            if isAIProcessing {
                aiProcessingOverlay
            }
        }
    }

    // MARK: - Subviews

    private var aiActionBar: some View {
        HStack(spacing: 6) {
            AIActionButton(title: "Refine", icon: "sparkles") {
                performAIAction(.refine)
            }
            AIActionButton(title: "Summarize", icon: "text.badge.minus") {
                performAIAction(.summarize)
            }
            AIActionButton(title: "Draft Intro", icon: "mic.badge.plus") {
                performAIAction(.draftIntro)
            }
        }
        .disabled(isAIProcessing)
        .opacity(isAIProcessing ? 0.5 : 1.0)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text(message)
                .font(.system(size: 10))
                .lineLimit(1)
            Spacer()
            Button { aiError = nil } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }

    private var controlBar: some View {
        HStack(spacing: 16) {
            // Play — closes notch and starts scrolling
            Button(action: startScrolling) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                    Text("Start")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(state.text.isEmpty ? Color.white.opacity(0.05) : Color.green.opacity(0.8))
                )
                .foregroundStyle(state.text.isEmpty ? Color.gray.opacity(0.3) : Color.white)
            }
            .buttonStyle(.plain)
            .disabled(state.text.isEmpty)

            // Paste from clipboard
            Button(action: pasteFromClipboard) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Paste from clipboard")

            // Clear
            Button(action: {
                state.text = ""
                state.reset()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(state.text.isEmpty ? Color.secondary.opacity(0.3) : Color.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .disabled(state.text.isEmpty)
            .help("Clear script")

            Spacer()

            // Speed control
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Slider(
                    value: .init(
                        get: { state.config.speed },
                        set: { state.config.speed = $0 }
                    ),
                    in: 10...80,
                    step: 5
                )
                .frame(width: 70)
            }
        }
        .padding(.horizontal, 4)
    }

    private var aiProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .cornerRadius(12)
            VStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("AI processing…")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .allowsHitTesting(true)
    }

    // MARK: - Actions

    private func startScrolling() {
        state.reset()
        state.isScrolling = true
        // Close notch — teleprompter takes over in closed mode
        vm.close(force: true)
    }

    private func pasteFromClipboard() {
        guard let content = NSPasteboard.general.string(forType: .string),
              !content.isEmpty else { return }
        state.text = content
        state.reset()
    }

    private func performAIAction(_ action: TeleprompterAIAction) {
        guard let ai = pluginManager?.services.ai else { return }

        isAIProcessing = true
        aiError = nil

        Task {
            do {
                try await state.aiAssist(action: action, ai: ai)
                isAIProcessing = false
            } catch {
                aiError = error.localizedDescription
                isAIProcessing = false
            }
        }
    }
}

// MARK: - AI Action Button

struct AIActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 10, weight: .semibold))
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
