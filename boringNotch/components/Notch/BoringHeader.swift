//
//  BoringHeader.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import SwiftUI

struct BoringHeader: View {
    @Environment(BoringViewModel.self) var vm
    @Environment(\.settings) var settings
    var batteryModel = BatteryStatusViewModel.shared
    @Bindable var coordinator = BoringViewCoordinator.shared
    @State var tvm = ShelfStateViewModel.shared
    var body: some View {
        HStack(spacing: 0) {
            HStack {
                if (!tvm.isEmpty || coordinator.alwaysShowTabs) && settings.boringShelf {
                    TabSelectionView()
                        .padding(.leading, 8)
                } else if vm.notchState == .open {
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)

            // Only show black notch overlay when Liquid Glass effect is DISABLED and on screens with hardware notch
            // When Liquid Glass is enabled, this black shape conflicts with the glass appearance
            let currentScreen = NSScreen.screen(withUUID: coordinator.selectedScreenUUID)
            let hasHardwareNotch = (currentScreen?.safeAreaInsets.top ?? 0) > 0
            
            if vm.notchState == .open && hasHardwareNotch {
                if !settings.liquidGlassEffect {
                    Rectangle()
                        .fill(.black)
                        .frame(width: vm.closedNotchSize.width)
                        .mask {
                            NotchShape()
                        }
                } else {
                    // Invisible spacer to maintain layout when Liquid Glass is enabled
                    // Only on screens WITH hardware notch where we need to leave space for it
                    Color.clear
                        .frame(width: vm.closedNotchSize.width, height: 1)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 4) {
                if vm.notchState == .open {
                    if isHUDType(coordinator.sneakPeek.type) && coordinator.sneakPeek.show && settings.showOpenNotchHUD {
                        OpenNotchHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                            .padding(.trailing, 8)
                    } else {
                        if settings.showMirror {
                            Button(action: {
                                vm.toggleCameraPreview()
                            }) {
                                Capsule()
                                    .fill(.black)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        Image(systemName: "web.camera")
                                            .foregroundColor(.white)
                                            .padding()
                                            .imageScale(.medium)
                                    }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if settings.settingsIconInNotch {
                            Button(action: {
                                SettingsWindowController.shared.showWindow()
                            }) {
                                Capsule()
                                    .fill(.black)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        Image(systemName: "gear")
                                            .foregroundColor(.white)
                                            .padding()
                                            .imageScale(.medium)
                                    }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if settings.showBatteryIndicator {
                            BoringBatteryView(
                                batteryWidth: 30,
                                isCharging: batteryModel.isCharging,
                                isInLowPowerMode: batteryModel.isInLowPowerMode,
                                isPluggedIn: batteryModel.isPluggedIn,
                                levelBattery: batteryModel.levelBattery,
                                maxCapacity: batteryModel.maxCapacity,
                                timeToFullCharge: batteryModel.timeToFullCharge,
                                isForNotification: false
                            )
                        }
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environment(vm)
    }

    func isHUDType(_ type: SneakContentType) -> Bool {
        switch type {
        case .volume, .brightness, .backlight, .mic:
            return true
        default:
            return false
        }
    }
}

#Preview {
    BoringHeader().environment(BoringViewModel())
}
