//
//  NotchFaceManager.swift
//  boringNotch
//
//  Created by Alexander on 2025-12-29.
//

import Foundation
import AppKit
import Combine
import Defaults

class NotchFaceManager: ObservableObject {
    static let shared = NotchFaceManager()
    
    @Published var eyeOffset: CGSize = .zero
    @Published var isSleepy: Bool = false
    
    private var mouseMonitor: Any?
    private var idleTimer: Timer?
    private let idleThreshold: TimeInterval = 10.0
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMove(event.locationInWindow)
            return event
        }
        
        // Also monitor global mouse moves if possible, but local is usually enough for the notch
        // For global we'd need accessibility permissions
        
        resetIdleTimer()
    }
    
    private func handleMouseMove(_ location: NSPoint) {
        resetIdleTimer()
        
        // Calculate offset based on screen center
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let centerX = screenFrame.midX
            let centerY = screenFrame.midY
            
            let dx = (location.x - centerX) / (screenFrame.width / 2)
            let dy = (location.y - centerY) / (screenFrame.height / 2)
            
            // Limit offset to a small range
            DispatchQueue.main.async {
                self.eyeOffset = CGSize(width: dx * 2, height: -dy * 2)
                if self.isSleepy {
                    self.isSleepy = false
                    if Defaults[.selectedMood] == .sleepy {
                        Defaults[.selectedMood] = .neutral
                    }
                }
            }
        }
    }
    
    private func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleThreshold, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isSleepy = true
                // Optionally switch mood to sleepy
                // Defaults[.selectedMood] = .sleepy
            }
        }
    }
}
