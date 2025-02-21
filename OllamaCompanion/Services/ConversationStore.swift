import Foundation
import SwiftUI

/// Manages saving and loading conversations
class ConversationStore: ObservableObject {
    static let shared = ConversationStore()
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    @Published var conversations: [Conversation] = []
    private var conversationsURL: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("OllamaCompanion")
            .appendingPathComponent("conversations")
    }
    
    private init() {
        createDirectoryIfNeeded()
        loadConversations()
    }
    
    /// Saves a new conversation
    func saveConversation(_ conversation: Conversation) {
        guard let url = conversationsURL?.appendingPathComponent("\(conversation.id.uuidString).json") else { return }
        
        do {
            let data = try encoder.encode(conversation)
            try data.write(to: url)
            
            if let existingIndex = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations[existingIndex] = conversation
            } else {
                conversations.append(conversation)
            }
            conversations.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Error saving conversation: \(error)")
        }
    }
    
    /// Loads all saved conversations
    private func loadConversations() {
        guard let url = conversationsURL else { return }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            
            conversations = fileURLs.compactMap { fileURL in
                guard fileURL.pathExtension == "json" else { return nil }
                do {
                    let data = try Data(contentsOf: fileURL)
                    return try decoder.decode(Conversation.self, from: data)
                } catch {
                    return nil
                }
            }
            
            conversations.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Error loading conversations: \(error)")
        }
    }
    
    /// Creates the necessary directories for storing conversations
    private func createDirectoryIfNeeded() {
        guard let url = conversationsURL else { return }
        
        do {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("Error creating directory: \(error)")
        }
    }
    
    /// Deletes a conversation
    func deleteConversation(_ conversation: Conversation) {
        guard let url = conversationsURL?.appendingPathComponent("\(conversation.id.uuidString).json") else { return }
        
        do {
            try fileManager.removeItem(at: url)
            conversations.removeAll { $0.id == conversation.id }
        } catch {
            print("Error deleting conversation: \(error)")
        }
    }
} 