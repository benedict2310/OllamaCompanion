import Foundation
import Network
import SwiftUI
import CoreLocation

/// Custom error types for Ollama service
enum OllamaError: LocalizedError {
    case serverNotRunning
    case invalidResponse
    case networkError(Error)
    case localNetworkNotAvailable
    case invalidRequest
    case streamError
    case connectionError
    
    var errorDescription: String? {
        switch self {
        case .serverNotRunning:
            return "Ollama server is not running. Please start Ollama and try again."
        case .invalidResponse:
            return "Invalid response from Ollama server."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .localNetworkNotAvailable:
            return "Cannot connect to localhost. Please ensure Ollama is running and accessible."
        case .invalidRequest:
            return "Invalid request parameters."
        case .streamError:
            return "Error processing stream response."
        case .connectionError:
            return "Connection error. Please try again."
        }
    }
}

/// Service for interacting with the Ollama API
class OllamaService {
    // MARK: - Properties
    
    static let shared = OllamaService()
    private let monitor = NWPathMonitor(requiredInterfaceType: .loopback)
    private let monitorQueue = DispatchQueue(label: "com.ollamacompanion.networkMonitor")
    private let locationManager = LocationManager()
    
    private var baseURL: String {
        UserDefaults.standard.string(forKey: "ollamaAddress") ?? "http://localhost:11434"
    }
    
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Fetches available models from Ollama
    /// - Returns: Array of model names
    func fetchAvailableModels() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
            return response.models.map { $0.name }
        case 404:
            throw OllamaError.serverNotRunning
        default:
            throw OllamaError.invalidResponse
        }
    }
    
    /// Generates a chat completion using the specified model and messages
    /// - Parameters:
    ///   - messages: Array of previous messages for context
    ///   - model: The model to use for completion
    ///   - onUpdate: Callback for each chunk of the response
    func generateChatCompletion(messages: [Message], model: String, onUpdate: @escaping (String) -> Void) async throws {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw URLError(.badURL)
        }
        
        print("Generating chat completion with model: \(model)")
        
        // Get settings
        let temperature = UserDefaults.standard.double(forKey: "temperature")
        let maxTokens = UserDefaults.standard.integer(forKey: "maxTokens")
        let basePrompt = UserDefaults.standard.string(forKey: "basePrompt") ?? ""
        let includeLocalTime = UserDefaults.standard.bool(forKey: "includeLocalTime")
        let includeLocation = UserDefaults.standard.bool(forKey: "includeLocation")
        
        // Build system prompt with optional components
        var systemPrompt = basePrompt
        
        if includeLocalTime {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm"
            let localTime = dateFormatter.string(from: Date())
            systemPrompt += "\nUser's local time: \(localTime)"
        }
        
        if includeLocation, 
           let location = locationManager.currentLocation,
           let locationName = locationManager.locationName {
            systemPrompt += "\nUser's location: \(locationName) (coordinates: \(location.coordinate.latitude), \(location.coordinate.longitude))"
        }
        
        // Create chat messages array with system prompt if available
        var chatMessages = [ChatMessage]()
        if !systemPrompt.isEmpty {
            chatMessages.append(ChatMessage(role: "system", content: systemPrompt))
        }
        chatMessages.append(contentsOf: messages.map { ChatMessage(role: $0.isUser ? "user" : "assistant", content: $0.content) })
        
        let request = ChatRequest(
            model: model,
            messages: chatMessages,
            stream: true,
            options: ChatOptions(
                temperature: temperature,
                num_predict: maxTokens
            )
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("close", forHTTPHeaderField: "Connection")
        
        let jsonData = try JSONEncoder().encode(request)
        urlRequest.httpBody = jsonData
        
        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            var responseText = ""
            for try await line in bytes.lines {
                guard let data = line.data(using: .utf8),
                      let response = try? JSONDecoder().decode(ChatStreamResponse.self, from: data)
                else { continue }
                
                if let content = response.message?.content {
                    responseText += content
                    onUpdate(responseText)
                }
                
                if response.done {
                    break
                }
            }
        case 404:
            throw OllamaError.serverNotRunning
        default:
            throw OllamaError.invalidResponse
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                print("Localhost network is available")
            } else {
                print("Localhost network is unavailable")
                print("Network status: \(path.status)")
            }
        }
        monitor.start(queue: monitorQueue)
    }
}

// MARK: - Models

private struct ModelsResponse: Codable {
    let models: [ModelInfo]
}

private struct ModelInfo: Codable {
    let name: String
    let model: String
    let modified_at: String
    let size: Int64
    let digest: String
    let details: ModelDetails
    
    enum CodingKeys: String, CodingKey {
        case name, model, modified_at, size, digest, details
    }
}

private struct ModelDetails: Codable {
    let parent_model: String
    let format: String
    let family: String
    let families: [String]
    let parameter_size: String
    let quantization_level: String
}

// MARK: - Chat Models

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatOptions: Codable {
    let temperature: Double
    let num_predict: Int
}

private struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
    let options: ChatOptions
}

private struct ChatStreamResponse: Codable {
    let model: String
    let message: ChatMessage?
    let done: Bool
    let done_reason: String?
    let total_duration: Int64?
    let load_duration: Int64?
    let prompt_eval_count: Int?
    let prompt_eval_duration: Int64?
    let eval_count: Int?
    let eval_duration: Int64?
} 