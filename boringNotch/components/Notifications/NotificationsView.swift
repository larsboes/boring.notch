import SwiftUI

struct NotificationsView: View {
    @StateObject private var manager = NotificationCenterManager.shared
    @Namespace private var animation

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 5)

            if manager.authorizationStatus == .denied {
                permissionDeniedView
            } else if manager.notifications.isEmpty {
                emptyStateView
            } else {
                notificationList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Text("Notifications")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            if !manager.notifications.isEmpty {
                Button(action: {
                    withAnimation {
                        manager.markAllAsRead()
                    }
                }) {
                    Text("모두 읽음") // "Read All"
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: {
                    withAnimation {
                        manager.clearAll()
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("알림이 비활성화되어 있어요. 설정에서 켜주세요.") // "Notifications are disabled. Please enable in settings."
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open macOS settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Spacer()
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bell.badge")
                .font(.system(size: 32))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("배터리와 시스템 이벤트를 한 곳에서 확인하세요.") // "Check battery and system events in one place."
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(manager.notifications) { notification in
                    NotificationRow(notification: notification)
                        .transition(.scale.combined(with: .opacity))
                        .contextMenu {
                            Button("비우기") { // "Clear" / "Delete"
                                manager.removeNotification(notification)
                            }
                            if !notification.isRead {
                                Button("읽음 처리") { // "Mark as Read"
                                    manager.markAsRead(notification)
                                }
                            }
                        }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
}

struct NotificationRow: View {
    let notification: NotchNotification

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.date, relativeTo: Date())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(nsColor: .controlAccentColor).opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: notification.category.icon)
                    .foregroundStyle(Color(nsColor: .controlAccentColor))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(relativeDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(notification.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(notification.isRead ? Color.black.opacity(0.2) : Color(nsColor: .controlAccentColor).opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notification.isRead ? Color.white.opacity(0.08) : Color(nsColor: .controlAccentColor).opacity(0.4), lineWidth: 1)
        )
    }
}
