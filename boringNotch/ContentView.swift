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
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared

    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var brightnessManager = BrightnessManager.shared
    @ObservedObject var volumeManager = VolumeManager.shared
    @ObservedObject var stateMachine = NotchStateMachine.shared
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var anyDropDebounceTask: Task<Void, Never>?

    @State private var gestureProgress: CGFloat = .zero

    @State private var haptics: Bool = false

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
            && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
        {
            chinWidth = 640
        } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && vm.notchState == .closed && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && coordinator.musicLiveActivityEnabled && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, displayClosedNotchHeight - 12) + 20)
        } else if !coordinator.expandingView.show && vm.notchState == .closed
            && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace]
            && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, displayClosedNotchHeight - 12) + 20)
        }

        return chinWidth
    }

    // If the closed notch height is 0 (any display/setting), display a 10pt nearly-invisible notch
    // instead of fully hiding it. This preserves layout while avoiding visual artifacts.
    private var isNotchHeightZero: Bool { vm.effectiveClosedNotchHeight == 0 }

    private var displayClosedNotchHeight: CGFloat { isNotchHeightZero ? 10 : vm.effectiveClosedNotchHeight }

    var body: some View {
        // Calculate scale based on gesture progress only
        let gestureScale: CGFloat = {
            guard gestureProgress != 0 else { return 1.0 }
            let scaleFactor = 1.0 + gestureProgress * 0.01
            return max(0.6, scaleFactor)
        }()
        
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                let mainLayout = NotchLayout()
                    .frame(alignment: .top)
                    .padding(
                        .horizontal,
                        isDisplayStateOpen ? cornerRadiusInsets.opened.top : cornerRadiusInsets.closed.bottom
                    )
                    .padding([.horizontal, .bottom], isDisplayStateOpen ? 12 : 0)
                    .background {
                        ZStack {
                            if liquidGlassEffect {
                                // Get the current screen and window for Metal blur
                                let currentScreen = vm.screenUUID.flatMap { NSScreen.screen(withUUID: $0) } ?? NSScreen.main
                                let notchWindow = NSApp.windows.first { $0.contentView?.subviews.first(where: { $0 is NSHostingView<ContentView> }) != nil }
                                let captureRect = currentScreen.map { screen in
                                    LiquidGlassManager.captureRect(
                                        for: screen,
                                        notchSize: isDisplayStateOpen ? vm.notchSize : vm.closedNotchSize
                                    )
                                } ?? .zero
                                
                                LiquidGlassBackground(
                                    shape: Rectangle(),
                                    configuration: liquidGlassStyle.configuration,
                                    isActive: true,
                                    tintColor: musicManager.isPlaying ? Color(nsColor: musicManager.avgColor).opacity(0.3) : nil,
                                    isExpanded: isDisplayStateOpen,
                                    screen: currentScreen,
                                    excludingWindow: notchWindow,
                                    captureRect: captureRect
                                )
                            } else {
                                Color.black
                            }
                            
                            if (isHovering || vm.notchState == .open), let hoverImage = vm.backgroundImage {
                                Image(nsImage: hoverImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()
                            }
                        }
                    }
                    .clipShape(currentNotchShape)
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
                    .shadow(
                        color: ((isDisplayStateOpen || isHovering) && Defaults[.enableShadow])
                            ? .black.opacity(0.7) : .clear, radius: 6
                    )
                    // Removed conditional bottom padding when using custom 0 notch to keep layout stable
                    .opacity((isNotchHeightZero && vm.notchState == .closed) ? 0.01 : 1)
                
                mainLayout
                    .frame(height: isDisplayStateOpen ? vm.notchSize.height : nil)
                    .conditionalModifier(true) { view in
                        view
                            .animation(vm.notchState == .open ? StandardAnimations.open : StandardAnimations.close, value: vm.notchSize)
                            .animation(vm.notchState == .open ? StandardAnimations.open : StandardAnimations.close, value: vm.notchState)
                            .animation(.smooth, value: gestureProgress)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        if vm.notchState == .open {
                            vm.close()
                        } else {
                            doOpen()
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
                        if vm.notchState == .open && !isHovering && !vm.isBatteryPopoverActive {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if self.vm.notchState == .open && !self.isHovering && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: vm.notchState) { _, newState in
                        if newState == .closed && isHovering {
                            withAnimation {
                                isHovering = false
                            }
                        }
                    }
                    .onChange(of: vm.isBatteryPopoverActive) {
                        if !vm.isBatteryPopoverActive && !isHovering && vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if !self.vm.isBatteryPopoverActive && !self.isHovering && self.vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .contextMenu {
                        Button("Settings") {
                            SettingsWindowController.shared.showWindow()
                        }
                        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                        //                    Button("Edit") { // Doesnt work....
                        //                        let dn = DynamicNotch(content: EditPanelView())
                        //                        dn.toggle()
                        //                    }
                        //                    .keyboardShortcut("E", modifiers: .command)
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
        .compositingGroup()
        .scaleEffect(
            x: gestureScale,
            y: gestureScale,
            anchor: .top
        )
        .animation(.smooth, value: gestureProgress)
        .background(dragDetector)
        .preferredColorScheme(.dark)
        .environmentObject(vm)
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
        NotchContentRouter(
            displayState: stateMachine.displayState,
            albumArtNamespace: albumArtNamespace,
            coordinator: coordinator,
            musicManager: musicManager,
            batteryModel: batteryModel,
            closedNotchHeight: displayClosedNotchHeight,
            cornerRadiusScaleFactor: cornerRadiusScaleFactor,
            cornerRadiusInsets: cornerRadiusInsets
        )
        .onAppear {
            updateStateMachine()
        }
        .onChange(of: coordinator.helloAnimationRunning) { updateStateMachine() }
        .onChange(of: vm.notchState) { updateStateMachine() }
        .onChange(of: coordinator.currentView) { updateStateMachine() }
        .onChange(of: coordinator.sneakPeek.show) { updateStateMachine() }
        .onChange(of: coordinator.expandingView.show) { updateStateMachine() }
        .onChange(of: musicManager.isPlaying) { updateStateMachine() }
        .onChange(of: musicManager.isPlayerIdle) { updateStateMachine() }
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], delegate: GeneralDropTargetDelegate(isTargeted: $vm.generalDropTargeting))
    }

    private func updateStateMachine() {
        let input = NotchStateMachine.createInput(
            notchState: vm.notchState,
            currentView: coordinator.currentView,
            coordinator: coordinator,
            musicManager: musicManager,
            hideOnClosed: vm.hideOnClosed
        )
        NotchStateMachine.shared.update(with: input)

        // DEBUG: Trace state changes
        print("DEBUG: notchState=\(vm.notchState), currentView=\(coordinator.currentView), displayState=\(NotchStateMachine.shared.displayState)")
    }

    @ViewBuilder
    var dragDetector: some View {
        if Defaults[.boringShelf] && vm.notchState == .closed {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
            vm.dropEvent = true
            ShelfStateViewModel.shared.load(providers)
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
                    LiquidGlassBackground(
                        shape: Rectangle(),
                        configuration: liquidGlassStyle.configuration,
                        isActive: true,
                        tintColor: musicManager.isPlaying ? Color(nsColor: musicManager.avgColor).opacity(0.3) : nil,
                        isExpanded: isDisplayStateOpen
                    )
                    
                    // Optional background image on top of glass
                    if (isHovering || vm.notchState == .open), let hoverImage = vm.backgroundImage {
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
                    
                    if (isHovering || vm.notchState == .open), let hoverImage = vm.backgroundImage {
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

    private func handleHover(_ hovering: Bool) {
        if coordinator.firstLaunch { return }
        hoverTask?.cancel()
        
        if hovering {
            withAnimation(StandardAnimations.interactive) {
                isHovering = true
            }
            
            if vm.notchState == .closed && Defaults[.enableHaptics] {
                haptics.toggle()
            }
            
            guard vm.notchState == .closed,
                  !coordinator.sneakPeek.show,
                  Defaults[.openNotchOnHover] else { return }
            
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          self.isHovering,
                          !self.coordinator.sneakPeek.show,
                          !self.coordinator.helloAnimationRunning else { return }
                    
                    self.doOpen()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    withAnimation(StandardAnimations.interactive) {
                        self.isHovering = false
                    }
                    
                    if self.vm.notchState == .open && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
                        self.vm.close()
                    }
                }
            }
        }
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
            withAnimation(StandardAnimations.interactive) {
                isHovering = false
            }
            if !SharingStateManager.shared.preventNotchClose { 
                gestureProgress = .zero
                vm.close()
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
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}
