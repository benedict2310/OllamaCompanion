import SwiftUI
import CoreLocation

/// View for managing app settings and personalization
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("basePrompt") private var basePrompt: String = ""
    @AppStorage("temperature") private var temperature: Double = 0.7
    @AppStorage("maxTokens") private var maxTokens: Double = 2048
    @AppStorage("includeLocalTime") private var includeLocalTime: Bool = false
    @AppStorage("includeLocation") private var includeLocation: Bool = false
    @AppStorage("ollamaAddress") private var ollamaAddress: String = "http://localhost:11434"
    @AppStorage("defaultModel") private var defaultModel: String = "llama2"
    @StateObject private var locationManager = LocationManager()
    @StateObject private var ollamaManager = OllamaManager()
    @State private var isModelsExpanded = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title)
                    .bold()
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding(.bottom)
            
            // Settings Form
            Form {
                Section("Ollama Connection") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server Address")
                            .font(.headline)
                        HStack {
                            TextField("Ollama server address", text: $ollamaAddress)
                                .textFieldStyle(.roundedBorder)
                            Button("Reset") {
                                ollamaAddress = "http://localhost:11434"
                            }
                            .help("Reset to default address")
                        }
                        Text("Default: http://localhost:11434")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Model")
                                .font(.headline)
                            Spacer()
                            Picker("", selection: $defaultModel) {
                                ForEach(ollamaManager.models, id: \.self) { model in
                                    Text(model)
                                        .font(.system(.body, design: .monospaced))
                                        .tag(model)
                                }
                            }
                            .frame(width: 200)
                            .pickerStyle(.menu)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        DisclosureGroup(
                            isExpanded: $isModelsExpanded,
                            content: {
                                if ollamaManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.5)
                                } else if let error = ollamaManager.error {
                                    Text(error)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                } else if ollamaManager.models.isEmpty {
                                    Text("No models found")
                                        .foregroundColor(.secondary)
                                } else {
                                    List(ollamaManager.models, id: \.self) { model in
                                        HStack {
                                            if model == defaultModel {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                            }
                                            Text(model)
                                                .font(.system(.body, design: .monospaced))
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                    }
                                    .listStyle(.bordered)
                                    .frame(maxHeight: 150)
                                    .scrollContentBackground(.hidden)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            },
                            label: {
                                HStack {
                                    Text("Available Models")
                                        .font(.headline)
                                    Spacer()
                                    Button {
                                        Task {
                                            await ollamaManager.fetchModels()
                                        }
                                    } label: {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    .help("Refresh model list")
                                }
                            }
                        )
                    }
                }
                
                Section("Model Parameters") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Temperature")
                            .font(.headline)
                        HStack {
                            Slider(value: $temperature, in: 0...2)
                            Text(String(format: "%.2f", temperature))
                                .monospacedDigit()
                        }
                        Text("Controls randomness: 0 is focused, 2 is more creative")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Max Tokens")
                            .font(.headline)
                        HStack {
                            Slider(value: $maxTokens, in: 256...4096, step: 256)
                            Text("\(Int(maxTokens))")
                                .monospacedDigit()
                        }
                        Text("Maximum number of tokens to generate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Personalization") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base Prompt")
                            .font(.headline)
                        TextEditor(text: $basePrompt)
                            .frame(height: 100)
                            .font(.system(.body, design: .monospaced))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                        Text("Custom instructions added to every conversation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Include Local Time", isOn: $includeLocalTime)
                        .help("Add your local time to each conversation")
                    
                    Toggle("Include Location", isOn: $includeLocation)
                        .onChange(of: includeLocation) { _, newValue in
                            if newValue {
                                locationManager.requestLocationPermission()
                            }
                        }
                        .help("Add your approximate location to each conversation")
                    
                    if includeLocation {
                        if let error = locationManager.locationError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        } else {
                            switch locationManager.authorizationStatus {
                            case .notDetermined:
                                Text("Location permission not determined")
                                    .foregroundColor(.secondary)
                            case .restricted:
                                Text("Location access denied. Please enable in System Settings.")
                                    .foregroundColor(.red)
                            case .denied:
                                Text("Location access denied. Please enable in System Settings.")
                                    .foregroundColor(.red)
                            case .authorized:
                                if let location = locationManager.currentLocation {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if let locationName = locationManager.locationName {
                                            Text(locationName)
                                                .foregroundColor(.secondary)
                                        }
                                        Text("Coordinates: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                } else {
                                    Text("Acquiring location...")
                                        .foregroundColor(.secondary)
                                }
                            @unknown default:
                                Text("Unknown location status")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .padding()
        .frame(width: 500, height: 600)
        .task {
            await ollamaManager.fetchModels()
        }
        .onChange(of: ollamaManager.models) { _, newModels in
            // If the default model isn't available, pick the first available one
            if !newModels.isEmpty && !newModels.contains(defaultModel) {
                defaultModel = newModels[0]
            }
        }
    }
}

/// Manages Ollama server connection and model list
class OllamaManager: ObservableObject {
    @Published private(set) var models: [String] = []
    @Published private(set) var error: String?
    @Published private(set) var isLoading = false
    
    @MainActor
    func fetchModels() async {
        isLoading = true
        error = nil
        
        do {
            models = try await OllamaService.shared.fetchAvailableModels()
            
            // Check if the default model is available
            let defaultModel = UserDefaults.standard.string(forKey: "defaultModel") ?? "llama2"
            if !models.isEmpty && !models.contains(defaultModel) {
                // Set the first available model as default
                UserDefaults.standard.set(models[0], forKey: "defaultModel")
            }
        } catch {
            self.error = error.localizedDescription
            // Keep the last known models list in case of temporary server issues
        }
        
        isLoading = false
    }
    
    /// Gets the current default model or falls back to the first available one
    func getCurrentModel() -> String {
        let defaultModel = UserDefaults.standard.string(forKey: "defaultModel") ?? "llama2"
        if models.contains(defaultModel) {
            return defaultModel
        }
        return models.first ?? defaultModel
    }
}

/// Manages location services
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    @Published var currentLocation: CLLocation?
    @Published var locationName: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        
        // Use reduced accuracy by default
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        
        // Set distance filter to reduce update frequency
        locationManager.distanceFilter = 1000 // Updates only when moved 1km
        
        // Check initial authorization status
        authorizationStatus = locationManager.authorizationStatus
        
        // Start location updates if already authorized
        if authorizationStatus == .authorized {
            locationManager.startUpdatingLocation()
        }
    }
    
    private func updateLocationName(for location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    self?.locationName = nil
                    return
                }
                
                if let placemark = placemarks?.first {
                    var components: [String] = []
                    
                    if let city = placemark.locality {
                        components.append(city)
                    } else if let area = placemark.administrativeArea {
                        components.append(area)
                    }
                    
                    if let country = placemark.country {
                        components.append(country)
                    }
                    
                    self?.locationName = components.joined(separator: ", ")
                } else {
                    self?.locationName = nil
                }
            }
        }
    }
    
    func requestLocationPermission() {
        // Reset any previous errors
        locationError = nil
        
        // Check if location services are enabled at the system level
        if !CLLocationManager.locationServicesEnabled() {
            locationError = "Location services are disabled in System Settings"
            return
        }
        
        // Request authorization based on current status
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .restricted:
            locationError = "Location access is restricted by parental controls or system policy"
        case .denied:
            locationError = "Location access was denied. Please enable in System Settings"
        case .authorized:
            // Already authorized, start updating
            locationManager.startUpdatingLocation()
        @unknown default:
            locationError = "Unknown authorization status"
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorized:
                self.locationError = nil
                manager.startUpdatingLocation()
            case .denied:
                self.locationError = "Location access denied. Please enable in System Settings"
                manager.stopUpdatingLocation()
                self.currentLocation = nil
            case .restricted:
                self.locationError = "Location access is restricted"
                manager.stopUpdatingLocation()
                self.currentLocation = nil
            case .notDetermined:
                self.locationError = nil
                manager.stopUpdatingLocation()
                self.currentLocation = nil
            @unknown default:
                self.locationError = "Unknown location status"
                manager.stopUpdatingLocation()
                self.currentLocation = nil
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            guard let location = locations.last else { return }
            
            // Only update if accuracy is within reasonable bounds
            if location.horizontalAccuracy <= 1000 { // 1km accuracy is fine for our use case
                self.currentLocation = location
                self.locationError = nil
                self.updateLocationName(for: location)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            print("Location manager error: \(error.localizedDescription)")
            
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "Location access denied"
                case .locationUnknown:
                    self.locationError = "Unable to determine location"
                default:
                    self.locationError = "Failed to get location: \(clError.localizedDescription)"
                }
            } else {
                self.locationError = "Failed to get location: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    SettingsView()
} 