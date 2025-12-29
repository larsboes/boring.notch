//
//  BatterySettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import Defaults
import SwiftUI

struct Charge: View {
    @Default(.powerStatusNotificationSound) var powerStatusNotificationSound
    @Default(.lowBatteryNotificationLevel) var lowBatteryNotificationLevel
    @Default(.lowBatteryNotificationSound) var lowBatteryNotificationSound
    @Default(.highBatteryNotificationLevel) var highBatteryNotificationLevel
    @Default(.highBatteryNotificationSound) var highBatteryNotificationSound

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showBatteryIndicator) {
                    Text("Show battery indicator")
                }
                Defaults.Toggle(key: .showPowerStatusNotifications) {
                    Text("Show power status notifications")
                }
            } header: {
                Text("General")
            }
            Section {
                // toggle won't show if device is wall powered device
                if deviceHasBattery() {
                    Defaults.Toggle(key: .showBatteryPercentage) {
                        Text("Show battery percentage")
                    }
                }
                Defaults.Toggle(key: .showPowerStatusIcons) {
                    Text("Show power status icons")
                }
            } header: {
                Text("Battery Information")
            }
            
            Section {
                PickerSoundAlert(sounds: SystemSoundHelper.availableSystemSounds(), sound: $powerStatusNotificationSound)
                
                BatteryLevelPicker(
                    title: "Low Battery Notification",
                    level: $lowBatteryNotificationLevel,
                    sounds: SystemSoundHelper.availableSystemSounds(),
                    sound: $lowBatteryNotificationSound
                )
                
                BatteryLevelPicker(
                    title: "High Battery Notification",
                    level: $highBatteryNotificationLevel,
                    sounds: SystemSoundHelper.availableSystemSounds(),
                    sound: $highBatteryNotificationSound
                )
            } header: {
                Text("Notifications")
            }
        }
        .onAppear {
            Task { @MainActor in
                await XPCHelperClient.shared.isAccessibilityAuthorized()
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Battery")
    }
}

struct BatteryLevelPicker: View {
    let title: String
    @Binding var level: Int
    let sounds: [String]
    @Binding var sound: String
    
    var body: some View {
        HStack {
            Picker(title, selection: $level) {
                Text("Disabled").tag(0)
                ForEach(1...100, id: \.self) { level in
                    Text("\(level)%").tag(level)
                }
            }
            Divider()
            PickerSoundAlert(sounds: sounds, sound: $sound)
        }
    }
}

struct PickerSoundAlert: View {
    let sounds: [String]
    @Binding var sound: String
    
    var body: some View {
        Picker("Sound", selection: $sound) {
            Text("Disabled").tag("Disabled")
            ForEach(sounds, id: \.self) { sound in
                Text(sound).tag(sound)
            }
        }
    }
}
