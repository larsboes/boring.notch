//
//  BoringViewModel+Camera.swift
//  boringNotch
//
//  Extracted camera-related methods from BoringViewModel.
//

import AppKit

extension BoringViewModel {
    func toggleCameraPreview() {
        if isRequestingAuthorization {
            return
        }

        switch webcamService.authorizationStatus {
        case .authorized:
            if webcamService.isSessionRunning {
                webcamService.stopSession()
                isCameraExpanded = false
            } else if webcamService.cameraAvailable {
                webcamService.startSession()
                isCameraExpanded = true
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)

                let alert = NSAlert()
                alert.messageText = "Camera Access Required"
                alert.informativeText = "Please allow camera access in System Settings."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")

                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }

                NSApp.setActivationPolicy(.accessory)
                NSApp.deactivate()
            }

        case .notDetermined:
            isRequestingAuthorization = true
            webcamService.checkAndRequestVideoAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isRequestingAuthorization = false
            }

        default:
            break
        }
    }
}
