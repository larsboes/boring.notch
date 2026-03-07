import SwiftUI

struct TeleprompterClosedView: View {
    let state: TeleprompterState
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.isScrolling ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
                .opacity(state.isScrolling ? 0.8 : 0.5)
            
            if !state.text.isEmpty {
                Text(state.isScrolling ? "Scrolling" : "Ready")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
    }
}
