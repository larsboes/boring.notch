//
//  WeatherSettingsView.swift
//  boringNotch
//
//  Created by Lars Boes on 29/12/2024.
//

import SwiftUI
import Defaults

struct WeatherSettings: View {
    @ObservedObject private var weatherManager = WeatherManager.shared
    @Default(.showWeather) var showWeather: Bool
    @Default(.openWeatherMapApiKey) var apiKey: String

    var body: some View {
        Form {
            Defaults.Toggle(key: .showWeather) {
                Text("Show weather")
            }
            .onChange(of: showWeather) { _, newValue in
                if newValue {
                    // When weather is enabled, check and request location if needed
                    weatherManager.checkLocationAuthorization()
                }
            }

            Section(header: Text("API Key")) {
                SecureField("OpenWeatherMap API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                if apiKey.isEmpty {
                    Link(destination: URL(string: "https://openweathermap.org/api")!) {
                        Label("Get your free API key", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            }

            Section(header: Text("Location Access")) {
                if weatherManager.locationAuthorizationStatus == .notDetermined {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location access is required to show weather information.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        Text("Enable 'Show weather' above to request location permission.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                } else if weatherManager.locationAuthorizationStatus == .denied || weatherManager.locationAuthorizationStatus == .restricted {
                    Text("Location access is denied. Please enable it in System Settings.")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Open Location Settings") {
                        if let settingsURL = URL(
                            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
                        ) {
                            NSWorkspace.shared.open(settingsURL)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Location access granted")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            
            if let weather = weatherManager.currentWeather {
                Section(header: Text("Current Weather")) {
                    HStack {
                        Text("Location")
                        Spacer()
                        Text(weather.location)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(weather.temperatureString)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Condition")
                        Spacer()
                        Text(weather.condition)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(weather.lastUpdated, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Weather")
        .onAppear {
            weatherManager.checkLocationAuthorization()
        }
    }
}
