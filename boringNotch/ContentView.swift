//
//  ContentView.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import AVFoundation
import Combine
import Defaults
import KeyboardShortcuts
import SwiftUI
import SwiftUIIntrospect

@MainActor
struct ContentView: View {
    @Environment(BoringViewModel.self) var vm
    @Environment(\.pluginManager) var pluginManager

    @Bindable var coordinator = BoringViewCoordinator.shared
    @State var brightnessManager = BrightnessManager()
    @State var volumeManager = VolumeManager()
    var stateMachine = NotchStateMachine.shared

    @State private var anyDropDebounceTask: Task<Void, Never>?

    @State private var gestureProgress: CGFloat = .zero

    @State private var haptics: Bool = false
    
    // Helper to access music service from plugin manager
    private var musicService: any MusicServiceProtocol {
        pluginManager?.services.music ?? MusicService(manager: MusicManager())
    }

    @Namespace var albumArtNamespace

    @Default(.showNotHumanFace) var showNotHumanFace
    @Default(.liquidGlassEffect) var liquidGlassEffect
    @Default(.liquidGlassStyle) var liquidGlassStyle

    // Use standardized animations from StandardAnimations enum
    private let animationSpring = StandardAnimations.interactive

    private let extendedHoverPadding: CGFloat = 30
    private let zeroHeightHoverPadding: CGFloat = 10

    // MARK: - Display State Helpers

    /// Check if the display state is open (use this instead of vm.notchState for consistency)
    private var isDisplayStateOpen: Bool {
        if case .open = stateMachine.displayState {
            return true
        }
        return false
    }

    // MARK: - Corner Radius Scaling
    private var cornerRadiusScaleFactor: CGFloat? {
        guard Defaults[.cornerRadiusScaling] else { return nil }
        let effectiveHeight = displayClosedNotchHeight
        guard effectiveHeight > 0 else { return nil }
        return effectiveHeight / 38.0
    }
    
    private var topCornerRadius: CGFloat {
        // If the notch is open, return the opened radius.
        if isDisplayStateOpen {
            return cornerRadiusInsets.opened.top
        }

        // For the closed notch, scale if enabled
        let baseClosedTop = cornerRadiusInsets.closed.top
        guard let scaleFactor = cornerRadiusScaleFactor else {
            return displayClosedNotchHeight > 0 ? baseClosedTop : 0
        }
        return max(0, baseClosedTop * scaleFactor)
    }

    private var currentNotchShape: NotchShape {
        // Scale bottom corner radius for closed notch shape when scaling is enabled.
        let baseClosedBottom = cornerRadiusInsets.closed.bottom
        let bottomCorner: CGFloat

        if isDisplayStateOpen {
            bottomCorner = cornerRadiusInsets.opened.bottom
        } else if let scaleFactor = cornerRadiusScaleFactor {
            bottomCorner = max(0, baseClosedBottom * scaleFactor)
        } else {
            bottomCorner = displayClosedNotchHeight > 0 ? baseClosedBottom : 0
        }

        return NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCorner
        )
    }

    private var computedChinWidth: CGFloat {
        var chinWidth: CGFloat = vm.closedNotchSize.width

        if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && vm.notchState == .closed && Defaults[.showPowerStatusNotifications] {
            chinWidth = 640
        } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && vm.notchState == .closed && (musicService.playbackState.isPlaying || !musicService.isPlayerIdle)
            && coordinator.musicLiveActivityEnabled && !vm.hideOnClosed {
            chinWidth += (2 * max(0, displayClosedNotchHeight - 12) + 20)
        } else if !coordinator.expandingView.show && vm.notchState == .closed
            && (!musicService.playbackState.isPlaying && musicService.isPlayerIdle) && Defaults[.showNotHumanFace]
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
                    .padding(
                        .horizontal,
                        isDisplayStateOpen ? cornerRadiusInsets.opened.top : cornerRadiusInsets.closed.bottom
                    )
                    .padding([.horizontal, .bottom], isDisplayStateOpen ? 12 : 0)
                    .clipShape(currentNotchShape)
                    .background {
                        ZStack {
                            if liquidGlassEffect {
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
                            color: ((isDisplayStateOpen || vm.isHoveringNotch) && Defaults[.enableShadow])
                                ? .black.opacity(0.7) : .clear, radius: 6
                        )
                    }
                    .overlay {
                        // Luminous border for liquid glass effect (works in both states)
                        if liquidGlassEffect {
                            currentNotchShape
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(liquidGlassStyle.configuration.borderOpacity * (isDisplayStateOpen ? 1.0 : 0.6)),
                                            .white.opacity(liquidGlassStyle.configuration.borderOpacity * 0.3 * (isDisplayStateOpen ? 1.0 : 0.6)),
                                            .white.opacity(liquidGlassStyle.configuration.borderOpacity * 0.5 * (isDisplayStateOpen ? 1.0 : 0.6))
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: liquidGlassStyle.configuration.borderWidth
                                )
                        }
                    }
                    .overlay(alignment: .top) {
                        displayClosedNotchHeight.isZero && vm.notchState == .closed ? nil
                            : Rectangle()
                                .fill(liquidGlassEffect ? .clear : .black)
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
                    .conditionalModifier(Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .down) { translation, phase in
                                handleDownGesture(translation: translation, phase: phase)
                            }
                    }
                    .conditionalModifier(Defaults[.closeGestureEnabled] && Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .up) { translation, phase in
                                handleUpGesture(translation: translation, phase: phase)
                            }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .sharingDidFinish)) { _ in
                        // Cancel any pending close when sharing finishes
                        if !SharingStateManager.shared.preventNotchClose {
                            vm.cancelPendingClose()
                        }
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .contextMenu {
                        Button("Settings") {
                            SettingsWindowController.shared.showWindow()
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
                if !SharingStateManager.shared.preventNotchClose {
                    vm.close()
                }
            }
        }
    }

    @ViewBuilder
    func NotchLayout() -> some View {
        @Bindable var vm = vm
        NotchContentRouter(
            displayState: stateMachine.displayState,
            albumArtNamespace: albumArtNamespace,
            coordinator: coordinator,
            closedNotchHeight: displayClosedNotchHeight,
            cornerRadiusScaleFactor: cornerRadiusScaleFactor,
            cornerRadiusInsets: cornerRadiusInsets
        )
    }

    private func updateStateMachine() {
        let input = NotchStateMachine.createInput(
            notchState: vm.notchState,
            currentView: coordinator.currentView,
            coordinator: coordinator,
            musicService: musicService,
            pluginManager: pluginManager,
            hideOnClosed: vm.hideOnClosed
        )
        NotchStateMachine.shared.update(with: input)

        // DEBUG: Trace state changes
        // print("DEBUG: notchState=\(vm.notchState), currentView=\(coordinator.currentView), displayState=\(NotchStateMachine.shared.displayState)")
    }

    @ViewBuilder
    var dragDetector: some View {
        @Bindable var vm = vm
        if Defaults[.boringShelf] && vm.notchState == .closed {
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
    
    // MARK: - Notch Background
    
    @ViewBuilder
    private var notchBackground: some View {
        Group {
            if liquidGlassEffect {
                // Liquid glass effect with optional background image overlay
                ZStack {
                    Rectangle()
                        .swiftGlassEffect(
                            isEnabled: true,
                            tintColor: musicService.playbackState.isPlaying ? Color(nsColor: musicService.avgColor).opacity(0.3) : nil
                        )
                    
                    // Optional background image on top of glass
                    if vm.isHoveringNotch || vm.notchState == .open, let hoverImage = vm.backgroundImage {
                        Image(nsImage: hoverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .opacity(0.25)
                    }
                }
            } else {
                // Classic solid black background
                ZStack {
                    Color.black
                        .ignoresSafeArea()
                    
                    if vm.isHoveringNotch || vm.notchState == .open, let hoverImage = vm.backgroundImage {
                        Image(nsImage: hoverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    }
                }
            }
        }
    }

    private func doOpen() {
        withAnimation(StandardAnimations.interactive) {
            vm.open()
        }
    }

    // MARK: - Hover Management
    // Deprecated: Now handled by TrackingAreaView and BoringViewModel
    private func handleHover(_ hovering: Bool) {
        // Kept for compatibility if needed, but logic moved to VM
    }

    // MARK: - Gesture Handling

    private func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .closed else { return }

        if phase == .ended {
            withAnimation(StandardAnimations.interactive) { gestureProgress = .zero }
            return
        }

        withAnimation(StandardAnimations.interactive) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * 20
        }

        if translation > Defaults[.gestureSensitivity] {
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
            withAnimation(StandardAnimations.interactive) {
                gestureProgress = .zero
            }
            doOpen()
        }
    }

    private func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .open && !vm.isHoveringCalendar else { return }

        withAnimation(StandardAnimations.interactive) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * -20
        }

        if phase == .ended {
            withAnimation(StandardAnimations.interactive) {
                gestureProgress = .zero
            }
        }

        if translation > Defaults[.gestureSensitivity] {

            if !SharingStateManager.shared.preventNotchClose { 
                gestureProgress = .zero
                vm.close(force: true)
            }

            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }
    }
}

struct FullScreenDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: () -> Void

    func dropEntered(info _: DropInfo) {
        isTargeted = true
    }

    func dropExited(info _: DropInfo) {
        isTargeted = false
    }

    func performDrop(info _: DropInfo) -> Bool {
        isTargeted = false
        onDrop()
        return true
    }

}

struct GeneralDropTargetDelegate: DropDelegate {
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        return false
    }
}

#Preview {
    let vm = BoringViewModel()
    ContentView()
        .environment(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
        .onAppear {
            vm.open()
        }
}
