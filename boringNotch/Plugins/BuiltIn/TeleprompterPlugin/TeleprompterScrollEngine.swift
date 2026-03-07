import Foundation

/// Pure logic for teleprompter scrolling.
/// No dependencies on SwiftUI or AppKit.
struct TeleprompterScrollEngine: Sendable {
    struct Config: Codable, Sendable {
        var speed: Double // lines per minute or pixels per second? Let's say pixels per second.
        var fontSize: Double
        var pauseAtParagraph: Bool
        var pauseDuration: TimeInterval
    }
    
    struct State: Codable, Sendable {
        var scrollPosition: Double
        var isScrolling: Bool
        var lastUpdate: Date?
    }
    
    /// Calculate current scroll position based on time elapsed.
    func calculatePosition(in state: State, config: Config, now: Date = Date()) -> Double {
        guard state.isScrolling, let lastUpdate = state.lastUpdate else {
            return state.scrollPosition
        }
        
        let elapsed = now.timeIntervalSince(lastUpdate)
        return state.scrollPosition + (config.speed * elapsed)
    }
    
    /// Parse text into sections using "##" as markers.
    func parseSections(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        return lines.filter { $0.hasPrefix("##") }
            .map { $0.replacingOccurrences(of: "##", with: "").trimmingCharacters(in: .whitespaces) }
    }
}
