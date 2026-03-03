//
//  PluginMusicControlsView.swift
//  boringNotch
//
//  Temporary stub to satisfy build while the full implementation is integrated.
//

import SwiftUI

public struct PluginMusicControlsView: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
            Text("Music Controls")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.thinMaterial, in: Capsule())
    }
}

#Preview {
    PluginMusicControlsView()
        .padding()
}
