import Foundation
import SwiftUI

/// Manages the chat state and messages
@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published private(set) var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isProcessing: Bool = false
    @Published var availableModels: [String] = []
    @Published var selectedModel: String = "x/llama3.2-vision:latest"
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var currentConversation: Conversation? {
        didSet {
            if let conversation = currentConversation {
                messages = conversation.messages
                selectedModel = conversation.model
            } else {
                messages = []
            }
        }
    }
    
    private let store = ConversationStore.shared
    private var currentTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        Task {
            await fetchModels()
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetches available models from Ollama
    func fetchModels() async {
        isProcessing = true
        errorMessage = nil
        showError = false
        
        do {
            let models = try await OllamaService.shared.fetchAvailableModels()
            await MainActor.run {
                self.availableModels = models
                // Only change the selected model if it's not available and we have other options
                if !models.isEmpty && !models.contains(selectedModel) {
                    self.selectedModel = models[0]
                }
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isProcessing = false
            }
            print("Error fetching models: \(error)")
        }
    }
    
    /// Sends a new message to the chat
    /// - Parameter content: The content of the message
    @MainActor
    func sendMessage(_ content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isProcessing else { return }
        
        isProcessing = true
        errorMessage = nil
        showError = false
        
        let messageContent = content
        
        let userMessage = Message(content: messageContent)
        messages.append(userMessage)
        
        let assistantMessage = Message(content: "", isUser: false)
        messages.append(assistantMessage)
        
        // Create new conversation if needed
        if currentConversation == nil {
            currentConversation = Conversation(
                id: UUID(),
                title: Conversation.generateTitle(from: messages),
                messages: messages,
                model: selectedModel
            )
            store.saveConversation(currentConversation!)
        }
        
        currentTask = Task {
            do {
                try await OllamaService.shared.generateChatCompletion(
                    messages: Array(messages.dropLast()),
                    model: selectedModel
                ) { newContent in
                    Task { @MainActor in
                        assistantMessage.content = newContent
                        self.messages[self.messages.count - 1].content = newContent
                        self.updateCurrentConversation()
                    }
                }
            } catch {
                // Handle different error cases
                if error is CancellationError || (error as NSError).code == NSURLErrorCancelled {
                    // Request was cancelled by user
                } else {
                    errorMessage = error.localizedDescription
                    showError = true
                }
                
                // Clean up the empty message
                if messages.last?.isUser == false && messages.last?.content.isEmpty == true {
                    messages.removeLast()
                }
                
                updateCurrentConversation()
            }
            isProcessing = false
            currentTask = nil
        }
    }
    
    /// Stops the current generation
    func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
        
        // Remove the last message if it's empty
        if let lastMessage = messages.last, !lastMessage.isUser && lastMessage.content.isEmpty {
            messages.removeLast()
            updateCurrentConversation()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateCurrentConversation() {
        guard var conversation = currentConversation else { return }
        
        // Create updated conversation with current messages
        conversation = Conversation(
            id: conversation.id,
            title: Conversation.generateTitle(from: messages),
            messages: messages,
            model: selectedModel,
            createdAt: conversation.createdAt,
            updatedAt: Date()
        )
        
        // Update current conversation and save
        currentConversation = conversation
        store.saveConversation(conversation)
    }
    
    /// Loads a specific conversation
    func loadConversation(_ conversation: Conversation) {
        guard conversation.id != currentConversation?.id else { return }
        
        // Save current conversation if it exists
        if let current = currentConversation {
            store.saveConversation(current)
        }
        
        currentConversation = conversation
        inputText = ""
        isProcessing = false
        errorMessage = nil
        showError = false
    }
    
    /// Starts a new conversation
    func startNewConversation() {
        // Save current conversation if it exists
        if let conversation = currentConversation {
            store.saveConversation(conversation)
        }
        
        currentConversation = nil
        inputText = ""
        isProcessing = false
        errorMessage = nil
        showError = false
    }
} 