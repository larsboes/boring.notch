import Defaults
import SwiftUI

enum NotificationDeliveryStyle: String, CaseIterable, Defaults.Serializable {
    case banner
    case soundOnly
    
    var localizedName: String {
        switch self {
        case .banner: return "Banner & Sound"
        case .soundOnly: return "Sound Only"
        }
    }
}

struct NotificationsSettingsView: View {
    @StateObject private var manager = NotificationCenterManager.shared
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Permission Status")
                    Spacer()
                    Text(authorizationLabel)
                        .foregroundStyle(.secondary)
                }
                
                if manager.authorizationStatus != .authorized {
                    Button("Request permission") {
                        manager.requestAuthorization()
                    }
                }
            } header: {
                Text("General")
            }
            
            Section {
                Defaults.Toggle(key: .showShelfNotifications) {
                    Text("Shelf Events")
                }
                Defaults.Toggle(key: .showSystemNotifications) {
                    Text("System Events")
                }
                Defaults.Toggle(key: .showInfoNotifications) {
                    Text("Info & Updates")
                }
            } header: {
                Text("Sources")
            }
            
            Section {
                Picker("Delivery Style", selection: Defaults.binding(.notificationDeliveryStyle)) {
                    ForEach(NotificationDeliveryStyle.allCases, id: \.self) { style in
                        Text(style.localizedName).tag(style)
                    }
                }
                
                Defaults.Toggle(key: .notificationSoundEnabled) {
                    Text("Play sound")
                }
                
                Defaults.Toggle(key: .respectDoNotDisturb) {
                    Text("Respect Do Not Disturb / Focus")
                }
                
                Stepper(value: Defaults.binding(.notificationRetentionDays), in: 1...30) {
                    Text("Keep history for \(Defaults[.notificationRetentionDays]) days")
                }
            } header: {
                Text("History")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Notifications")
        .onAppear {
            manager.refreshAuthorizationStatus()
        }
    }

    private var authorizationLabel: String {
        switch manager.authorizationStatus {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not determined"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
}
