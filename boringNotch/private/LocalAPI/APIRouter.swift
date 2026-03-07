import Foundation

enum APIHTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

struct APIRequest {
    let method: APIHTTPMethod
    let path: String
    let headers: [String: String]
    let body: Data
}

final class APIRouter {
    typealias NotchStateProvider = @Sendable () async -> APINotchState
    typealias CommandHandler = @Sendable () async throws -> Void

    private let notchState: NotchStateProvider
    private let openNotch: CommandHandler
    private let closeNotch: CommandHandler
    private let toggleNotch: CommandHandler

    init(
        notchState: @escaping NotchStateProvider,
        openNotch: @escaping CommandHandler,
        closeNotch: @escaping CommandHandler,
        toggleNotch: @escaping CommandHandler
    ) {
        self.notchState = notchState
        self.openNotch = openNotch
        self.closeNotch = closeNotch
        self.toggleNotch = toggleNotch
    }

    func route(_ request: APIRequest) async -> APIHTTPResponse {
        switch (request.method, request.path) {
        case (.get, "/api/v1/notch/state"):
            let state = await notchState()
            return .json(APIResponseEnvelope.success(state))

        case (.post, "/api/v1/notch/open"):
            return await runCommand(openNotch)

        case (.post, "/api/v1/notch/close"):
            return await runCommand(closeNotch)

        case (.post, "/api/v1/notch/toggle"):
            return await runCommand(toggleNotch)

        case (.get, "/api/v1/events"):
            return .json(status: 400, APIResponseEnvelope<APIErrorData>.failure("Use WebSocket upgrade for /api/v1/events"))

        case (.get, _), (.post, _):
            return .json(status: 404, APIResponseEnvelope<APIErrorData>.failure("Route not found"))
        }
    }

    private func runCommand(_ command: CommandHandler) async -> APIHTTPResponse {
        do {
            try await command()
            return .json(APIResponseEnvelope<APIErrorData>.success())
        } catch {
            return .json(status: 500, APIResponseEnvelope<APIErrorData>.failure(error.localizedDescription))
        }
    }
}
