//
//  drop.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on  04/08/24.
//

import Foundation
import SwiftUI


public class BoringAnimations {
    @Published var notchStyle: Style = .notch
    
    init() {
        self.notchStyle = .notch
    }
    
    var animation: Animation {
        if #available(macOS 14.0, *), notchStyle == .notch {
            Animation.spring(.bouncy(duration: 0.4))
        } else {
            Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
        }
    }
    
    // Shared interactive spring for movement/resizing to avoid conflicting animations
    static let interactiveSpring = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)
    
    static let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    static let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
    
    static let helloAnimation = Animation.easeInOut(duration: 4.0)
}
