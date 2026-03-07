import Foundation
import Observation

@MainActor
@Observable
final class TeleprompterState {
    var text: String = ""
    var config = TeleprompterScrollEngine.Config(
        speed: 30, // px/s
        fontSize: 16,
        pauseAtParagraph: true,
        pauseDuration: 2.0
    )

    var scrollPosition: Double = 0
    var isScrolling: Bool = false {
        didSet {
            if isScrolling {
                lastUpdate = Date()
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    private var engine = TeleprompterScrollEngine()
    private var lastUpdate: Date?
    private var timer: Timer?

    func toggleScrolling() {
        isScrolling.toggle()
    }

    func reset() {
        isScrolling = false
        scrollPosition = 0
        lastUpdate = nil
    }

    /// Domain-level AI assist — delegates to the service protocol.
    func aiAssist(action: TeleprompterAIAction, ai: any AITextGenerationService) async throws {
        guard ai.isAvailable else {
            throw AIError.providerUnavailable(
                "No AI provider available. Install Ollama or use macOS 26+ for on-device AI."
            )
        }

        let result: String
        switch action {
        case .refine:
            result = try await ai.rewrite(text, style: .professional)
        case .summarize:
            result = try await ai.summarize(text)
        case .draftIntro:
            result = try await ai.draftIntro(topic: text, durationSeconds: 60)
        }

        self.text = result
        self.reset()
    }

    func update(now: Date = Date()) {
        guard isScrolling else { return }

        let state = TeleprompterScrollEngine.State(
            scrollPosition: scrollPosition,
            isScrolling: isScrolling,
            lastUpdate: lastUpdate
        )

        scrollPosition = engine.calculatePosition(in: state, config: config, now: now)
        lastUpdate = now
    }

    // MARK: - Timer Management

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        // Timer is already invalidated by stopTimer() when isScrolling is set to false.
        // This is a safety net — Timer.invalidate() is thread-safe.
    }
}

// MARK: - AI Action Enum (type-safe, no raw strings)

enum TeleprompterAIAction: String, Codable, Sendable {
    case refine
    case summarize
    case draftIntro = "draft-intro"
}
