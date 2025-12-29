//
//  WeatherManager.swift
//  boringNotch
//
//  Created by Arsh Anwar on 26/12/25.
//

import Foundation
import CoreLocation
import SwiftUI
import Combine
import WeatherKit
import Defaults

// MARK: - Weather Models

struct WeatherData {
    let temperature: Double
    let condition: String
    let symbolName: String
    let humidity: Double
    let windSpeed: Double
    let feelsLike: Double
    let high: Double
    let low: Double
    let location: String
    let lastUpdated: Date
    
    var temperatureString: String {
        return String(format: "%.0f°", temperature)
    }
    
    var systemIconName: String {
        return symbolName
    }
    
    var humidityInt: Int {
        return Int(humidity * 100)
    }
}

// MARK: - WeatherManager

@MainActor
class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()
    
    @Published var currentWeather: WeatherData?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService.shared
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let geocoder = CLGeocoder()
    private var isRequestingLocation = false
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    func checkLocationAuthorization() {
        locationAuthorizationStatus = locationManager.authorizationStatus
        
        switch locationAuthorizationStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startUpdatingWeather()
        case .denied, .restricted:
            errorMessage = "Location access denied"
        @unknown default:
            break
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            locationAuthorizationStatus = manager.authorizationStatus
            
            if locationAuthorizationStatus == .authorizedAlways {
                startUpdatingWeather()
            }
        }
    }
    
    func startUpdatingWeather() {
        fetchWeather()
        
        // Update weather every 30 minutes
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
    }
    
    func stopUpdatingWeather() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func fetchWeather() {
        guard locationAuthorizationStatus == .authorizedAlways else {
            return
        }
        
        // Prevent multiple simultaneous location requests
        guard !isRequestingLocation else {
            return
        }
        
        isRequestingLocation = true
        locationManager.requestLocation()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            isRequestingLocation = false
            fetchWeatherData(for: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isRequestingLocation = false
            errorMessage = "Failed to get location: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func fetchWeatherData(for location: CLLocation) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Fetch weather using OpenWeatherMap (for local testing without Apple Developer Account)
                let weatherData = try await OpenWeatherMapService.shared.fetchWeather(for: location)
                
                await MainActor.run {
                    self.currentWeather = weatherData
                    self.errorMessage = nil
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("Weather fetch error: \(error)")
                }
            }
        }
    }
    
    nonisolated deinit {
        Task { @MainActor in
            stopUpdatingWeather()
        }
    }
}

// MARK: - OpenWeatherMap Service

private struct OpenWeatherResponse: Codable {
    let weather: [OpenWeatherCondition]
    let main: OpenWeatherMain
    let wind: OpenWeatherWind
    let name: String
    let dt: TimeInterval
}

private struct OpenWeatherCondition: Codable {
    let id: Int
    let main: String
    let description: String
    let icon: String
}

private struct OpenWeatherMain: Codable {
    let temp: Double
    let feels_like: Double
    let temp_min: Double
    let temp_max: Double
    let humidity: Double
}

private struct OpenWeatherWind: Codable {
    let speed: Double
}

class OpenWeatherMapService {
    static let shared = OpenWeatherMapService()

    func fetchWeather(for location: CLLocation) async throws -> WeatherData {
        let apiKey = Defaults[.openWeatherMapApiKey]
        guard !apiKey.isEmpty else {
            throw NSError(domain: "OpenWeatherMap", code: 401, userInfo: [NSLocalizedDescriptionKey: "Please add your OpenWeatherMap API key in Settings > Weather"])
        }

        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&appid=\(apiKey)&units=metric"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "OpenWeatherMap", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenWeatherMap", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch weather data"])
        }

        let decoded = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)

        return WeatherData(
            temperature: decoded.main.temp,
            condition: decoded.weather.first?.main ?? "Unknown",
            symbolName: mapIconToSFSymbol(icon: decoded.weather.first?.icon ?? ""),
            humidity: decoded.main.humidity / 100.0,
            windSpeed: decoded.wind.speed * 3.6,
            feelsLike: decoded.main.feels_like,
            high: decoded.main.temp_max,
            low: decoded.main.temp_min,
            location: decoded.name,
            lastUpdated: Date(timeIntervalSince1970: decoded.dt)
        )
    }

    private func mapIconToSFSymbol(icon: String) -> String {
        switch icon {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.stars.fill"
        case "02d": return "cloud.sun.fill"
        case "02n": return "cloud.moon.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "smoke.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d": return "cloud.sun.rain.fill"
        case "10n": return "cloud.moon.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "snowflake"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}
