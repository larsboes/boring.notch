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
    @Environment(\.settings) var settings

    @Environment(BoringViewCoordinator.self) var coordinator
    @State var brightnessManager = BrightnessManager(eventBus: PluginEventBus())
    @State var volumeManager = VolumeManager(eventBus: PluginEventBus())
    @Environment(NotchStateMachine.self) var stateMachine
    @Environment(\.showSettingsWindow) var showSettingsWindow

    @State private var anyDropDebounceTask: Task<Void, Never>?

    @State var gestureProgress: CGFloat = .zero

    @State var haptics: Bool = false

    var musicService: any MusicServiceProtocol {
        pluginManager?.services.music ?? MusicService(manager: MusicManager())
    }

    @Namespace var albumArtNamespace

    var isDisplayStateOpen: Bool {
        if case .open = stateMachine.displayState { return true }
        return false
    }

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

    func doOpen() {
        withAnimation(StandardAnimations.interactive) {
            vm.open()
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
