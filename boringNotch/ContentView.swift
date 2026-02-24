//
//  ContentView.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import AVFoundation
import Combine
import SwiftUI
import SwiftUIIntrospect

@MainActor
struct ContentView: View {
    @Environment(BoringViewModel.self) var vm
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.bindableSettings) var settings

    @Environment(BoringViewCoordinator.self) var coordinator
    @State var brightnessManager = BrightnessManager(eventBus: PluginEventBus())
    @State var volumeManager = VolumeManager(eventBus: PluginEventBus())
    @Environment(NotchStateMachine.self) var stateMachine
    @Environment(\.showSettingsWindow) var showSettingsWindow

    @State private var anyDropDebounceTask: Task<Void, Never>?

    @State private var gestureProgress: CGFloat = .zero

    @State private var haptics: Bool = false
    
    // Helper to access music service from plugin manager
    private var musicService: any MusicServiceProtocol {
        pluginManager?.services.music ?? MusicService(manager: MusicManager())
    }

    @Namespace var albumArtNamespace

    // MARK: - Display State Helpers

    /// Check if the display state is open (use this instead of vm.notchState for consistency)
    private var isDisplayStateOpen: Bool {
        if case .open = stateMachine.displayState {
            return true
        }
        return false
    }

    // MARK: - Animation Progress (for smooth visual interpolation)

    /// Progress from closed (0) to open (1), derived from notchSize which already animates.
    /// This avoids the "middle step" where size animates but other visuals snap.
    private var animationProgress: CGFloat {
        let closedWidth = vm.closedNotchSize.width
        let openWidth = openNotchSize.width
        let currentWidth = vm.notchSize.width

        // Avoid division by zero
        guard openWidth > closedWidth else { return 0 }

        // Clamp to 0-1 range
        let progress = (currentWidth - closedWidth) / (openWidth - closedWidth)
        return max(0, min(1, progress))
    }

    /// Linear interpolation helper
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    // MARK: - Corner Radius Scaling
    private var cornerRadiusScaleFactor: CGFloat? {
        guard settings.cornerRadiusScaling else { return nil }
        let effectiveHeight = displayClosedNotchHeight
        guard effectiveHeight > 0 else { return nil }
        return effectiveHeight / 38.0
    }
    
    private var topCornerRadius: CGFloat {
        // Calculate closed corner radius (with optional scaling)
        let baseClosedTop = cornerRadiusInsets.closed.top
        let closedRadius: CGFloat
        if let scaleFactor = cornerRadiusScaleFactor {
            closedRadius = max(0, baseClosedTop * scaleFactor)
        } else {
            closedRadius = displayClosedNotchHeight > 0 ? baseClosedTop : 0
        }

        // Interpolate between closed and open based on animation progress
        return lerp(closedRadius, cornerRadiusInsets.opened.top, animationProgress)
    }

    private var bottomCornerRadius: CGFloat {
        // Calculate closed corner radius (with optional scaling)
        let baseClosedBottom = cornerRadiusInsets.closed.bottom
        let closedRadius: CGFloat
        if let scaleFactor = cornerRadiusScaleFactor {
            closedRadius = max(0, baseClosedBottom * scaleFactor)
        } else {
            closedRadius = displayClosedNotchHeight > 0 ? baseClosedBottom : 0
        }

        // Interpolate between closed and open based on animation progress
        return lerp(closedRadius, cornerRadiusInsets.opened.bottom, animationProgress)
    }

    private var currentNotchShape: NotchShape {
        return NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }

    private var computedChinWidth: CGFloat {
        var chinWidth: CGFloat = vm.closedNotchSize.width

        if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && vm.notchState == .closed && settings.showPowerStatusNotifications {
            chinWidth = 640
        } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && vm.notchState == .closed && (musicService.playbackState.isPlaying || !musicService.isPlayerIdle)
            && settings.musicLiveActivityEnabled && !vm.hideOnClosed {
            chinWidth += (2 * max(0, displayClosedNotchHeight - 12) + 20)
        } else if !coordinator.expandingView.show && vm.notchState == .closed
            && (!musicService.playbackState.isPlaying && musicService.isPlayerIdle) && settings.showNotHumanFace
            && !vm.hideOnClosed {
            chinWidth += (2 * max(0, displayClosedNotchHeight - 12) + 20)
        }

        return chinWidth
    }

    // If the closed notch height is 0 (any display/setting), display a 10pt nearly-invisible notch
    // instead of fully hiding it. This preserves layout while avoiding visual artifacts.
    private var isNotchHeightZero: Bool { vm.effectiveClosedNotchHeight == 0 }

    private var displayClosedNotchHeight: CGFloat { isNotchHeightZero ? 10 : vm.effectiveClosedNotchHeight }

    // MARK: - State Observation
    
    private struct StateSnapshot: Equatable {
        let helloAnimationRunning: Bool
        let notchState: NotchState
        let currentView: NotchViews
        let sneakPeekShow: Bool
        let expandingViewShow: Bool
        let isPlaying: Bool
        let isPlayerIdle: Bool
    }

    private var currentStateSnapshot: StateSnapshot {
        StateSnapshot(
            helloAnimationRunning: coordinator.helloAnimationRunning,
            notchState: vm.notchState,
            currentView: coordinator.currentView,
            sneakPeekShow: coordinator.sneakPeek.show,
            expandingViewShow: coordinator.expandingView.show,
            isPlaying: musicService.playbackState.isPlaying,
            isPlayerIdle: musicService.isPlayerIdle
        )
    }

    var body: some View {
        @Bindable var vm = vm
        // Inject shelf service into view model
        let _ = { vm.shelfService = pluginManager!.services.shelf }()
        
        // Calculate scale based on gesture progress only
        let gestureScale: CGFloat = {
            guard gestureProgress != 0 else { return 1.0 }
            let scaleFactor = 1.0 + gestureProgress * 0.01
            return max(0.6, scaleFactor)
        }()
        
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                NotchContentRouter(
                    displayState: stateMachine.displayState,
                    albumArtNamespace: albumArtNamespace,
                    coordinator: coordinator,
                    closedNotchHeight: displayClosedNotchHeight,
                    cornerRadiusScaleFactor: cornerRadiusScaleFactor,
                    cornerRadiusInsets: cornerRadiusInsets
                )
                    .onAppear {
                        updateStateMachine()
                    }
                    .onChange(of: currentStateSnapshot) { _, _ in updateStateMachine() }
                    .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], delegate: GeneralDropTargetDelegate(isTargeted: $vm.generalDropTargeting))
                    .frame(alignment: .top)
                    // Smoothly interpolate padding based on animation progress
                    .padding(
                        .horizontal,
                        lerp(cornerRadiusInsets.closed.bottom, cornerRadiusInsets.opened.top, animationProgress)
                    )
                    .padding([.horizontal, .bottom], lerp(0, 12, animationProgress))
                    .clipShape(currentNotchShape)
                    .background {
                        ZStack {
                            if settings.liquidGlassEffect {
                                // Metal capture logic removed - using SwiftGlass
                                Rectangle()
                                    .swiftGlassEffect(
                                        isEnabled: true,
                                        tintColor: musicService.playbackState.isPlaying ? Color(nsColor: musicService.avgColor).opacity(0.3) : nil
                                    )
                            } else {
                                Color.black
                            }
                            
                            if vm.isHoveringNotch || vm.notchState == .open, let hoverImage = vm.backgroundImage {
                                Image(nsImage: hoverImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()
                            }
                        }
                        .clipShape(currentNotchShape)
                        .shadow(
                            // Smoothly fade shadow based on animation progress
                            color: (animationProgress > 0 && settings.enableShadow)
                                ? .black.opacity(0.7 * animationProgress) : .clear, radius: 6
                        )
                    }
                    .overlay {
                        // Luminous border for liquid glass effect (works in both states)
                        if settings.liquidGlassEffect {
                            // Smoothly interpolate border opacity (0.6 closed → 1.0 open)
                            let borderMultiplier = lerp(0.6, 1.0, animationProgress)
                            currentNotchShape
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(settings.liquidGlassStyle.configuration.borderOpacity * borderMultiplier),
                                            .white.opacity(settings.liquidGlassStyle.configuration.borderOpacity * 0.3 * borderMultiplier),
                                            .white.opacity(settings.liquidGlassStyle.configuration.borderOpacity * 0.5 * borderMultiplier)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: settings.liquidGlassStyle.configuration.borderWidth
                                )
                        }
                    }
                    .overlay(alignment: .top) {
                        displayClosedNotchHeight.isZero && vm.notchState == .closed ? nil
                            : Rectangle()
                                .fill(settings.liquidGlassEffect ? .clear : .black)
                                .frame(height: 1)
                                .padding(.horizontal, topCornerRadius)
                    }
                    .opacity((isNotchHeightZero && vm.notchState == .closed) ? 0.01 : 1)
                    .frame(height: isDisplayStateOpen ? vm.notchSize.height : nil)
                    // Single animation for phase transitions (animations handled in ViewModel)
                    // Keep gesture progress animation separate for responsive feedback
                    .animation(.smooth, value: gestureProgress)
                    .background {
                        TrackingAreaView { signal in
                            vm.handleHoverSignal(signal)
                        }
                    }
                    .conditionalModifier(settings.enableGestures) { view in
                        view
                            .panGesture(direction: .down) { translation, phase in
                                handleDownGesture(translation: translation, phase: phase)
                            }
                    }
                    .conditionalModifier(settings.closeGestureEnabled && settings.enableGestures) { view in
                        view
                            .panGesture(direction: .up) { translation, phase in
                                handleUpGesture(translation: translation, phase: phase)
                            }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .sharingDidFinish)) { _ in
                        // Cancel any pending close when sharing finishes
                        if !pluginManager!.services.sharing.preventNotchClose {
                            vm.cancelPendingClose()
                        }
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .contextMenu {
                        Button("Settings") {
                            showSettingsWindow()
                        }
                        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                    }
                if vm.chinHeight > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.01))
                        .frame(width: computedChinWidth, height: vm.chinHeight)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: windowSize.width, maxHeight: windowSize.height, alignment: .top)

        .scaleEffect(
            x: gestureScale,
            y: gestureScale,
            anchor: .top
        )
        .animation(.smooth, value: gestureProgress)
        .background(dragDetector)
        .preferredColorScheme(.dark)
        .environment(vm)
        .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
            anyDropDebounceTask?.cancel()

            if isTargeted {
                if vm.notchState == .closed {
                    coordinator.currentView = .shelf
                    doOpen()
                }
                return
            }

            anyDropDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                if vm.dropEvent {
                    vm.dropEvent = false
                    return
                }

                vm.dropEvent = false
                if !pluginManager!.services.sharing.preventNotchClose {
                    vm.close()
                }
            }
        }
    }

    private func updateStateMachine() {
        let input = NotchStateMachine.createInput(
            notchState: vm.notchState,
            currentView: coordinator.currentView,
            coordinator: coordinator,
            musicService: musicService,
            pluginManager: pluginManager,
            hideOnClosed: vm.hideOnClosed,
            settings: settings
        )
        stateMachine.update(with: input)

        // DEBUG: Trace state changes
        // print("DEBUG: notchState=\(vm.notchState), currentView=\(coordinator.currentView), displayState=\(stateMachine.displayState)")
    }

    @ViewBuilder
    var dragDetector: some View {
        @Bindable var vm = vm
        if settings.boringShelf && vm.notchState == .closed {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
            vm.dropEvent = true
            pluginManager!.services.shelf.load(providers)
            return true
        }
        } else {
            EmptyView()
        }
    }

    private func doOpen() {
        withAnimation(StandardAnimations.interactive) {
            vm.open()
        }
    }

    // MARK: - Gesture Handling

    private func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        let result = NotchGestureCoordinator.handleDown(
            translation: translation, phase: phase, notchState: vm.notchState,
            sensitivity: settings.gestureSensitivity
        )
        applyGestureResult(result, openAction: { doOpen() })
    }

    private func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        let result = NotchGestureCoordinator.handleUp(
            translation: translation, phase: phase,
            notchState: vm.notchState,
            isHoveringCalendar: vm.isHoveringCalendar,
            preventClose: pluginManager!.services.sharing.preventNotchClose,
            sensitivity: settings.gestureSensitivity
        )
        applyGestureResult(result, closeAction: { vm.close(force: true) })
    }

    private func applyGestureResult(
        _ result: NotchGestureCoordinator.GestureResult,
        openAction: (() -> Void)? = nil,
        closeAction: (() -> Void)? = nil
    ) {
        switch result {
        case .progress(let value):
            withAnimation(StandardAnimations.interactive) { gestureProgress = value }
        case .reset:
            withAnimation(StandardAnimations.interactive) { gestureProgress = .zero }
        case .triggerOpen:
            if settings.enableHaptics { haptics.toggle() }
            withAnimation(StandardAnimations.interactive) { gestureProgress = .zero }
            openAction?()
        case .triggerClose:
            gestureProgress = .zero
            closeAction?()
            if settings.enableHaptics { haptics.toggle() }
        }
    }
}

#Preview {
    let vm = BoringViewModel()
    ContentView()
        .environment(vm)
        .environment(NotchStateMachine(settings: MockNotchSettings()))
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
        .onAppear {
            vm.open()
        }
}
