//
//  BoringViewModel+Observers.swift
//  boringNotch
//
//  Extracted from BoringViewModel — observer setup and sizing computations.
//

import SwiftUI

extension BoringViewModel {

    // MARK: - Observer Setup

    func setupDetectorObserver() {
        observerSetup.setupDetectorObserver(screenUUID: screenUUID) { [weak self] (shouldHide: Bool) in
            guard let self else { return }
            self.hideOnClosedDebounceTask?.cancel()
            self.hideOnClosedDebounceTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .milliseconds(400))
                } catch { return }
                guard let self, self.notchState == .closed else { return }
                if self.hideOnClosed != shouldHide {
                    withAnimation(.smooth) {
                        self.hideOnClosed = shouldHide
                    }
                }
            }
        }
    }

    func setupBackgroundImageObserver() {
        observerSetup.setupBackgroundImageObserver { [weak self] image in
            self?.backgroundImage = image
        }
    }

    func setupNotchHeightObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name.notchHeightChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateNotchSize()
            }
        }
    }

    func updateNotchSize() {
        let result = sizeCalculator.updateNotchSize(
            screenUUID: self.screenUUID,
            currentState: self.notchState
        )

        withAnimation(.smooth(duration: 0.3)) {
            if result.shouldUpdateNotchSize {
                self.notchSize = result.closedSize
            }

            if let screenFrame = getScreenFrame(self.screenUUID) {
                let width = openNotchSize.width
                let height = openNotchSize.height
                let x = screenFrame.midX - (width / 2)
                let y = screenFrame.maxY - height

                let region = CGRect(x: x, y: y, width: width, height: height)
                self.services.dragDrop.updateNotchRegion(region)
            }
        }
    }

    // MARK: - Effective Sizing

    var effectiveClosedNotchHeight: CGFloat {
        sizeCalculator.effectiveClosedNotchHeight(
            screenUUID: screenUUID,
            hideOnClosed: hideOnClosed,
            sneakPeekActive: coordinator.sneakPeek.show,
            expandingViewActive: coordinator.expandingView.show,
            expandingViewType: coordinator.expandingView.type,
            coordinator: coordinator,
            pluginPreferredHeight: pluginPreferredHeight
        )
    }

    var chinHeight: CGFloat {
        sizeCalculator.chinHeight(
            screenUUID: screenUUID,
            notchState: notchState,
            effectiveClosedHeight: effectiveClosedNotchHeight
        )
    }

    var effectiveClosedNotchSize: CGSize {
        let currentHeight = effectiveClosedNotchHeight
        let inactiveHeight = max(10, sizeCalculator.inactiveNotchSize.height)

        let hasLiveActivity = currentHeight > inactiveHeight + 2 || pluginPreferredHeight != nil

        var size = getClosedNotchSize(
            settings: displaySettings,
            screenUUID: screenUUID,
            hasLiveActivity: hasLiveActivity
        )

        size.height = currentHeight

        let isFaceActive = !services.music.playbackState.isPlaying &&
                           services.music.isPlayerIdle &&
                           settings.showNotHumanFace

        let isMusicActive = (services.music.playbackState.isPlaying || !services.music.isPlayerIdle) &&
                            settings.musicLiveActivityEnabled

        if coordinator.expandingView.type == .battery && coordinator.expandingView.show && settings.showPowerStatusNotifications {
            size.width = 640
        } else if (isMusicActive || isFaceActive) && !hideOnClosed {
            size.width += (2 * max(0, size.height - 12) + 20)
        }

        return size
    }
}
