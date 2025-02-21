import Foundation

/// Represents a chat conversation
struct Conversation: Codable, Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let messages: [Message]
    let model: String
    
    init(
        id: UUID = UUID(),
        title: String,
        messages: [Message],
        model: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.model = model
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Creates a title from the first message if available
    static func generateTitle(from messages: [Message]) -> String {
        if let firstMessage = messages.first {
            let content = firstMessage.content
            let words = content.split(separator: " ").prefix(6).joined(separator: " ")
            return words + (content.count > words.count ? "..." : "")
        }
        return "New Conversation"
    }
} 