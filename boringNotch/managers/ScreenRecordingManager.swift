//
//  ScreenRecordingManager.swift
//  boringNotch
//
//  Created by Alexander on 2025-12-29.
//

import Foundation
import AppKit
import Combine

class ScreenRecordingManager: ObservableObject {
    static let shared = ScreenRecordingManager()
    
    @Published var isRecording: Bool = false
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkRecordingStatus()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkRecordingStatus() {
        let isCaptured = CGDisplayIsCaptured(CGMainDisplayID())
        if isRecording != isCaptured {
            DispatchQueue.main.async {
                self.isRecording = isCaptured
            }
        }
    }
}
