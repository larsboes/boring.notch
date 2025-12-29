//
//  AppearanceSettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import AVFoundation
import AppKit
import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct Appearance: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.mirrorShape) var mirrorShape
    @Default(.sliderColor) var sliderColor
    @Default(.backgroundImageURL) var backgroundImageURL: URL?
    @Default(.liquidGlassEffect) var liquidGlassEffect
    @Default(.liquidGlassStyle) var liquidGlassStyle

    let icons: [String] = ["logo2"]
    @State private var selectedIcon: String = "logo2"
    var body: some View {
        Form {
            Section {
                Toggle("Always show tabs", isOn: $coordinator.alwaysShowTabs)
                Defaults.Toggle(key: .settingsIconInNotch) {
                    Text("Show settings icon in notch")
                }

            } header: {
                Text("General")
            }

            Section {
                Defaults.Toggle(key: .coloredSpectrogram) {
                    Text("Colored spectrogram")
                }
                Defaults
                    .Toggle("Player tinting", key: .playerColorTinting)
                Defaults.Toggle(key: .lightingEffect) {
                    Text("Enable blur effect behind album art")
                }
                Picker("Slider color", selection: $sliderColor) {
                    ForEach(SliderColorEnum.allCases, id: \.self) { option in
                        Text(option.rawValue)
                    }
                }
            } header: {
                Text("Media")
            }

            Section {
                Defaults.Toggle(key: .liquidGlassEffect) {
                    HStack {
                        Text("Liquid Glass Effect")
                        Text("Beta")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                if liquidGlassEffect {
                    Picker("Glass Style", selection: $liquidGlassStyle) {
                        ForEach(LiquidGlassStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    
                    LabeledContent {
                        Slider(value: .init(
                            get: { Defaults[.liquidGlassBlurRadius] },
                            set: { 
                                Defaults[.liquidGlassBlurRadius] = $0
                                LiquidGlassManager.shared.blurRadius = Float($0)
                            }
                        ), in: 5...50, step: 5)
                        .frame(width: 150)
                    } label: {
                        Text("Blur Intensity")
                    }
                    
                    // Permission status indicator
                    LabeledContent {
                        if LiquidGlassManager.shared.hasPermission {
                            Label("Granted", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Button("Grant Permission") {
                                Task {
                                    await LiquidGlassManager.shared.requestPermission()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    } label: {
                        Text("Screen Recording")
                    }
                }
                Defaults.Toggle(key: .enableShadow) {
                    Text("Enable shadow")
                }
            } header: {
                Text("Glass Effect")
            }
            
            Section {
                ZStack {
                    if let imageURL = backgroundImageURL,
                       let nsImage = NSImage(contentsOf: imageURL) {
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Button {
                                if let imageURL = backgroundImageURL {
                                    try? FileManager.default.removeItem(at: imageURL)
                                }
                                backgroundImageURL = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: -6)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 24))
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .contentShape(Rectangle())
                .onTapGesture {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [.image]
                    panel.message = "Select Background Image"
                    
                    if panel.runModal() == .OK, let sourceURL = panel.url {
                        if let copiedURL = BoringViewModel.copyBackgroundImageToAppStorage(sourceURL: sourceURL) {
                            backgroundImageURL = copiedURL
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Notch Background")
            }

            Section {
                Defaults.Toggle(key: .showMirror) {
                    Text("Enable boring mirror")
                }
                    .disabled(!checkVideoInput())
                Picker("Mirror shape", selection: $mirrorShape) {
                    Text("Circle")
                        .tag(MirrorShapeEnum.circle)
                    Text("Square")
                        .tag(MirrorShapeEnum.rectangle)
                }
                Defaults.Toggle(key: .showNotHumanFace) {
                    Text("Show cool face animation while inactive")
                }
            } header: {
                HStack {
                    Text("Additional features")
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Appearance")
    }

    func checkVideoInput() -> Bool {
        if AVCaptureDevice.default(for: .video) != nil {
            return true
        }

        return false
    }
}
