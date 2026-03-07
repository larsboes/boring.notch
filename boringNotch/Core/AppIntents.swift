import AppIntents

struct OpenNotchIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Notch"
    static var description = IntentDescription("Opens the boringNotch.")
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // We need access to the ViewModel to trigger this.
        // Usually handled via a shared singleton or DI.
        // Since we avoid singletons, we'll need a way to reach the coordinator.
        // For MVP, we'll emit an event.
        NotificationCenter.default.post(name: .openNotchIntent, object: nil)
        return .result()
    }
}

struct CloseNotchIntent: AppIntent {
    static var title: LocalizedStringResource = "Close Notch"
    static var description = IntentDescription("Closes the boringNotch.")
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .closeNotchIntent, object: nil)
        return .result()
    }
}

extension NSNotification.Name {
    static let openNotchIntent = NSNotification.Name("me.theboringteam.boringnotch.open")
    static let closeNotchIntent = NSNotification.Name("me.theboringteam.boringnotch.close")
}
