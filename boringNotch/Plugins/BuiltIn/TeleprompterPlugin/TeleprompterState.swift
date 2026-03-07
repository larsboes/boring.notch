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

    var textColor: PrompterColor = .white
    var countdownDuration: Int = 3 // 0 = off, 3 or 5
    let countdownState = CountdownState()
    var scrollPosition: Double = 0
    var isScrolling: Bool = false {
        didSet { updateTimerState() }
    }
    
    // Hover pause mechanic
    var isHovering: Bool = false {
        didSet { updateTimerState() }
    }
    
    
    // Content metrics for auto-stopping
    var contentHeight: Double = 0
    
    var isAtEnd: Bool {
        // Assume physical notch height is ~30px, buffer 40px to stop right around the last line
        contentHeight > 0 && scrollPosition >= (contentHeight - 40)
    }
    
    // Voice Feedback
    let micMonitor = MicrophoneMonitor()

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
    
    // MARK: - Minimalist Controls
    
    func goHome() {
        scrollPosition = 0
        lastUpdate = (isScrolling && !isHovering) ? Date() : nil
    }
    
    func increaseSpeed() {
        config.speed = min(config.speed + 10, 150)
    }
    
    func decreaseSpeed() {
        config.speed = max(config.speed - 10, 10)
    }

    /// Start presentation: countdown first (if enabled), then begin scrolling.
    /// The caller is responsible for closing the notch before calling this.
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

    func update(now: Date = Date()) {
        guard isScrolling, !isHovering else {
            // Keep lastUpdate fresh while paused so it doesn't jump when resumed
            lastUpdate = now
            return 
        }

        let state = TeleprompterScrollEngine.State(
            scrollPosition: scrollPosition,
            isScrolling: isScrolling,
            lastUpdate: lastUpdate
        )

        let newPosition = engine.calculatePosition(in: state, config: config, now: now)
        
        // Stop automatically if we've scrolled past the content
        let maxScroll = contentHeight > 0 ? (contentHeight - 40) : .infinity
        
        if newPosition >= maxScroll {
            // Reached the end
            isScrolling = false
            scrollPosition = maxScroll
            return
        }

        scrollPosition = newPosition
        lastUpdate = now
    }

    // MARK: - Timer Management
    
    private func updateTimerState() {
        if isScrolling {
            if !isHovering {
                micMonitor.startMonitoring()
            } else {
                micMonitor.stopMonitoring()
            }
            
            // We keep the timer running even when hovering to keep `lastUpdate` fresh,
            // so we resume smoothly.
            if timer == nil {
                lastUpdate = Date()
                startTimer()
            }
        } else {
            stopTimer()
            micMonitor.stopMonitoring()
        }
    }

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

// MARK: - Prompter Text Color (Foundation-only, SwiftUI Color extension in Views/)

enum PrompterColor: String, CaseIterable, Codable, Sendable {
    case white, warmWhite, yellow, green, cyan
}
