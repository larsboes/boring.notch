import Foundation
import Combine

@MainActor
final class LocalAPIServerController {
    private let eventBus: PluginEventBus
    private let viewModelProvider: () -> BoringViewModel

    private var server: LocalAPIServer?
    private var cancellables = Set<AnyCancellable>()

    init(eventBus: PluginEventBus, viewModelProvider: @escaping () -> BoringViewModel) {
        self.eventBus = eventBus
        self.viewModelProvider = viewModelProvider
    }

    func start() {
        guard server == nil else { return }

        let router = APIRouter(
            notchState: { [weak self] in
                await MainActor.run {
                    self?.currentNotchState() ?? APINotchState(
                        phase: "closed",
                        screen: "unknown",
                        size: APISize(width: 0, height: 0)
                    )
                }
            },
            openNotch: { [weak self] in
                await MainActor.run {
                    self?.viewModelProvider().open()
                    self?.server?.broadcast(APIEventPayload(type: "notch.opened", data: ["source": "api"]))
                }
            },
            closeNotch: { [weak self] in
                await MainActor.run {
                    self?.viewModelProvider().close(force: true)
                    self?.server?.broadcast(APIEventPayload(type: "notch.closed", data: ["source": "api"]))
                }
            },
            toggleNotch: { [weak self] in
                await MainActor.run {
                    self?.toggle()
                }
            }
        )

        let server = LocalAPIServer(router: router)
        do {
            try server.start()
            self.server = server
            subscribeToEvents()
        } catch {
            print("Failed to start Local API server: \(error)")
        }
    }

    func stop() {
        cancellables.removeAll()
        server?.stop()
        server = nil
    }

    private func currentNotchState() -> APINotchState {
        let vm = viewModelProvider()
        let phase: String = {
            switch vm.phase {
            case .closed: return "closed"
            case .opening: return "opening"
            case .open: return "open"
            case .closing: return "closing"
            }
        }()

        return APINotchState(
            phase: phase,
            screen: vm.screenUUID ?? "main",
            size: APISize(width: vm.notchSize.width, height: vm.notchSize.height)
        )
    }

    private func toggle() {
        let vm = viewModelProvider()
        if vm.phase == .closed || vm.phase == .closing {
            vm.open()
            server?.broadcast(APIEventPayload(type: "notch.opened", data: ["source": "api"]))
            return
        }

        vm.close(force: true)
        server?.broadcast(APIEventPayload(type: "notch.closed", data: ["source": "api"]))
    }

    private func subscribeToEvents() {
        eventBus.events
            .sink { [weak self] event in
                guard let self = self else { return }
                self.server?.broadcast(self.mapEvent(event))
            }
            .store(in: &cancellables)
    }

    private func mapEvent(_ event: any PluginEvent) -> APIEventPayload {
        APIEventPayload(
            type: mapEventType(event.type),
            data: [
                "sourcePluginId": event.sourcePluginId,
                "eventType": event.type.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: event.timestamp)
            ]
        )
    }

    private func mapEventType(_ type: PluginEventType) -> String {
        switch type {
        case .notchOpened:
            return "notch.opened"
        case .notchClosed:
            return "notch.closed"
        case .musicTrackChanged:
            return "music.changed"
        case .pluginActivated, .pluginDeactivated:
            return "plugin.stateChanged"
        default:
            return "plugin.event"
        }
    }
}
