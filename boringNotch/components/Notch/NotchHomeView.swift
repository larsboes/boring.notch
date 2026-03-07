//
//  NotchHomeView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-18.
//  Modified by Harsh Vardhan Goswami & Richard Kunkli & Mustafa Ramadan & Arsh Anwar
//

import Combine
import Defaults
import SwiftUI

// MARK: - Main View

struct NotchHomeView: View {
    @Environment(BoringViewModel.self) var vm
    @Environment(\.settings) var settings
    @Environment(\.pluginManager) var pluginManager
    @Environment(BoringViewCoordinator.self) var coordinator
    let albumArtNamespace: Namespace.ID

    var body: some View {
        mainContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 4)
            .transition(.opacity)
            .environment(\.albumArtNamespace, albumArtNamespace) // Inject namespace for plugins
    }

    private var shouldShowCamera: Bool {
        settings.showMirror
            && (pluginManager?.services.webcam.cameraAvailable ?? false)
            && vm.isCameraExpanded
    }
    
    private var shouldShowCalendar: Bool {
        settings.showCalendar
    }
    
    private var shouldShowWeather: Bool {
        settings.showWeather
    }
    
    private var additionalItemsCount: Int {
        var count = 0
        if shouldShowCalendar { count += 1 }
        if shouldShowWeather { count += 1 }
        if shouldShowCamera { count += 1 }
        return count
    }
    
    private var itemWidth: CGFloat {
        // Very basic width calculation to prevent overflow
        let maxAvailableWidth: CGFloat = 640 - 100 // 100 for music
        if additionalItemsCount == 0 { return maxAvailableWidth }
        
        // Base width, clamped to ensure it doesn't get too small or too large
        let calculatedWidth = maxAvailableWidth / CGFloat(additionalItemsCount)
        return min(max(calculatedWidth - 10, 80), 215)
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: additionalItemsCount >= 2 ? 10 : 15) {
            // Render Music Plugin
            if let pluginManager {
                pluginManager.expandedPanelView(for: "com.boringnotch.music")
                    .opacity(vm.notchState == .open ? 1 : 0)
                    .blur(radius: vm.notchState == .closed ? 30 : 0)
                    .animation(StandardAnimations.staggered(index: 0), value: vm.notchState)
            }

            if shouldShowCalendar {
                if let pluginManager {
                    pluginManager.expandedPanelView(for: "com.boringnotch.calendar")
                        .frame(width: itemWidth)
                        .onHover { isHovering in
                            vm.isHoveringCalendar = isHovering
                        }
                        .environment(vm)
                        .opacity(vm.notchState == .open ? 1 : 0)
                        .blur(radius: vm.notchState == .closed ? 30 : 0)
                        .animation(StandardAnimations.staggered(index: 1), value: vm.notchState)
                        .transition(.opacity)
                }
            }

            if shouldShowWeather {
                if let pluginManager {
                    pluginManager.expandedPanelView(for: "com.boringnotch.weather")
                        .frame(width: itemWidth)
                        .environment(vm)
                        .opacity(vm.notchState == .open ? 1 : 0)
                        .blur(radius: vm.notchState == .closed ? 30 : 0)
                        .animation(StandardAnimations.staggered(index: 2), value: vm.notchState)
                        .transition(.opacity)
                }
            }

            if shouldShowCamera {
                if let pluginManager {
                    pluginManager.expandedPanelView(for: "com.boringnotch.webcam")
                        .scaledToFit()
                        .opacity(vm.notchState == .closed ? 0 : 1)
                    // Do not blur the camera view to prevent "Unable to render flattened version" errors
                        .animation(StandardAnimations.staggered(index: 3), value: vm.notchState)
                }
            }
        }
        .padding(.horizontal, 4)
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
    }
}
