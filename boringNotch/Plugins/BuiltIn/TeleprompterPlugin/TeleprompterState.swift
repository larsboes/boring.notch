import Foundation
import Observation

@MainActor
@Observable
final class TeleprompterState {
    var text: String = ""
    var config = TeleprompterScrollEngine.Config(
        speed: 30,
        fontSize: 16,
        pauseAtParagraph: true,
        pauseDuration: 2.0
    )

    var textColor: PrompterColor = .white
    var countdownDuration: Int = 3
    let countdownState = CountdownState()
    var scrollPosition: Double = 0

    var isScrolling: Bool = false {
        didSet { updateTimerState() }
    }

    var isHovering: Bool = false {
        didSet { updateTimerState() }
    }

    var contentHeight: Double = 0

    var isAtEnd: Bool {
        contentHeight > 0 && scrollPosition >= maxScroll
    }

    // MARK: - Timer Manager (extracted resource lifecycle)

    let timerManager = TeleprompterTimerManager()

    /// Convenience accessor for views that read mic level.
    var micMonitor: MicrophoneMonitor { timerManager.micMonitor }

    private var engine = TeleprompterScrollEngine()

    // MARK: - Constants

    /// Buffer pixels before content end to trigger auto-stop.
    private static let endBuffer: Double = 40
    /// Speed adjustment step.
    private static let speedStep: Double = 10
    private static let speedMin: Double = 10
    private static let speedMax: Double = 150

    private var maxScroll: Double {
        contentHeight > 0 ? (contentHeight - Self.endBuffer) : .infinity
    }

    // MARK: - Init

    init() {
        timerManager.onTick = { [weak self] now in
            self?.update(now: now)
        }
    }

    // MARK: - Controls

    func toggleScrolling() {
        isScrolling.toggle()
    }

    func reset() {
        isScrolling = false
        scrollPosition = 0
        timerManager.resetLastUpdate()
    }

    func goHome() {
        scrollPosition = 0
        timerManager.resetLastUpdate()
    }

    func increaseSpeed() {
        config.speed = min(config.speed + Self.speedStep, Self.speedMax)
    }

    func decreaseSpeed() {
        config.speed = max(config.speed - Self.speedStep, Self.speedMin)
    }

    /// Start presentation: countdown first (if enabled), then begin scrolling.
    func startPresentation() {
        if isAtEnd {
            scrollPosition = 0
        }
        countdownState.start(duration: countdownDuration) { [weak self] in
            self?.isScrolling = true
        }
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

    // MARK: - Scroll Update

    private func update(now: Date) {
        guard isScrolling, !isHovering else { return }

        let state = TeleprompterScrollEngine.State(
            scrollPosition: scrollPosition,
            isScrolling: isScrolling,
            lastUpdate: timerManager.lastUpdate
        )

        let newPosition = engine.calculatePosition(in: state, config: config, now: now)

        if newPosition >= maxScroll {
            isScrolling = false
            scrollPosition = maxScroll
            return
        }

        scrollPosition = newPosition
    }

    // MARK: - Timer State Coordination

    private func updateTimerState() {
        if isScrolling {
            if !isHovering {
                timerManager.micMonitor.startMonitoring()
            } else {
                timerManager.micMonitor.stopMonitoring()
            }

            if !timerManager.isRunning {
                timerManager.start()
            }
        } else {
            timerManager.stop()
        }
    }
}

// MARK: - AI Action Enum

enum TeleprompterAIAction: String, Codable, Sendable {
    case refine
    case summarize
    case draftIntro = "draft-intro"
}

// MARK: - Prompter Text Color

enum PrompterColor: String, CaseIterable, Codable, Sendable {
    case white, warmWhite, yellow, green, cyan
}
