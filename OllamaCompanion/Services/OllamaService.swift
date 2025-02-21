import Foundation
import Network

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
    
    private let baseURL = "http://localhost:11434/api"
    static let shared = OllamaService()
    private let monitor = NWPathMonitor(requiredInterfaceType: .loopback)
    private let monitorQueue = DispatchQueue(label: "com.ollamacompanion.networkmonitor")
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.shouldUseExtendedBackgroundIdleMode = true
        
        session = URLSession(configuration: config)
        setupNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Sends a chat completion request to Ollama with streaming response
    /// - Parameters:
    ///   - messages: Array of previous messages for context
    ///   - model: The model to use for completion
    ///   - onUpdate: Callback for each chunk of the response
    func generateChatCompletion(messages: [Message], model: String, onUpdate: @escaping (String) -> Void) async throws {
        guard let url = URL(string: "\(baseURL)/chat") else {
            throw URLError(.badURL)
        }
        
        print("Generating chat completion with model: \(model)")
        
        let chatMessages = messages.map { ChatMessage(role: $0.isUser ? "user" : "assistant", content: $0.content) }
        let request = ChatRequest(model: model, messages: chatMessages, stream: true)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("close", forHTTPHeaderField: "Connection")
        
        let jsonData = try JSONEncoder().encode(request)
        urlRequest.httpBody = jsonData
        
        do {
            let (bytes, response) = try await session.bytes(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaError.invalidResponse
            }
            
            print("Response status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 404 || httpResponse.statusCode == 503 {
                throw OllamaError.serverNotRunning
            }
            
            if httpResponse.statusCode != 200 {
                throw OllamaError.connectionError
            }
            
            var fullResponse = ""
            
            for try await line in bytes.lines {
                guard !line.isEmpty else { continue }
                print("Received line: \(line)")  // Debug print
                
                guard let data = line.data(using: .utf8) else {
                    print("Could not convert line to data")
                    continue
                }
                
                do {
                    let streamResponse = try JSONDecoder().decode(ChatStreamResponse.self, from: data)
                    
                    if let content = streamResponse.message?.content {
                        fullResponse += content
                        print("Updating with content: \(fullResponse)")  // Debug print
                        onUpdate(fullResponse)
                    }
                    
                    if streamResponse.done {
                        print("Stream completed")  // Debug print
                        // Send final update
                        onUpdate(fullResponse)
                        break
                    }
                } catch {
                    print("Error decoding stream response: \(error), line: \(line)")
                    continue
                }
            }
        } catch {
            print("Connection error: \(error)")
            if error is CancellationError || (error as NSError).code == NSURLErrorCancelled {
                print("Request was cancelled")
                return
            }
            throw OllamaError.connectionError
        }
    }
    
    /// Fetches available models from Ollama
    /// - Returns: Array of model names
    func fetchAvailableModels() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/tags") else {
            throw URLError(.badURL)
        }
        
        print("Fetching models from: \(url.absoluteString)")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("close", forHTTPHeaderField: "Connection")
        
        do {
            let (data, urlResponse) = try await session.data(from: url)
            
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw OllamaError.invalidResponse
            }
            
            print("Response status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 404 || httpResponse.statusCode == 503 {
                throw OllamaError.serverNotRunning
            }
            
            if httpResponse.statusCode != 200 {
                throw OllamaError.connectionError
            }
            
            let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
            let models = modelsResponse.models.map { $0.name }
            print("Found models: \(models)")
            return models
        } catch let error as OllamaError {
            throw error
        } catch {
            print("Network error details: \(error)")
            throw OllamaError.networkError(error)
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

private struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
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