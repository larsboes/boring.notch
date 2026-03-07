import SwiftUI

struct TeleprompterExpandedView: View {
    let state: TeleprompterState
    
    var body: some View {
        VStack(spacing: 12) {
            // Text Display Area
            ZStack {
                Color.black.opacity(0.1)
                
                ScrollView {
                    Text(state.text)
                        .font(.system(size: CGFloat(state.config.fontSize), weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.top, 40) // Starting space
                        .padding(.bottom, 100)
                        .offset(y: -state.scrollPosition)
                }
                .scrollDisabled(true) // Pure script-driven scroll
            }
            .frame(height: 120)
            .cornerRadius(12)
            .clipped()
            
            // Controls
            HStack(spacing: 20) {
                Button(action: { state.toggleScrolling() }) {
                    Image(systemName: state.isScrolling ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                }
                .buttonStyle(.plain)
                
                Button(action: { state.reset() }) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 24))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Speed")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Slider(value: .init(get: { state.config.speed }, set: { state.config.speed = $0 }), in: 5...100)
                        .frame(width: 80)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(width: 320)
    }
}
