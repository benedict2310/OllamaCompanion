import Foundation
import SwiftUI

/// Represents a single message in the chat
@Observable
class Message: Identifiable, Equatable, Codable {
    let id: UUID
    var content: String {
        didSet {
            updateThinkingContent()
        }
    }
    let timestamp: Date
    let isUser: Bool
    var thinkingContent: String?
    var showThinking: Bool
    
    init(id: UUID = UUID(), content: String, isUser: Bool = true) {
        self.id = id
        self.content = content
        self.timestamp = Date()
        self.isUser = isUser
        self.showThinking = false
        updateThinkingContent()
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
    
    private func updateThinkingContent() {
        if let thinkStart = content.range(of: "<think>"),
           let thinkEnd = content.range(of: "</think>") {
            let startIndex = content.index(after: thinkStart.upperBound)
            let thinkContent = content[startIndex..<thinkEnd.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let remainingContent = content[thinkEnd.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            
            thinkingContent = thinkContent
            content = remainingContent
        } else {
            thinkingContent = nil
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case timestamp
        case isUser
        case thinkingContent
        case showThinking
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        thinkingContent = try container.decodeIfPresent(String.self, forKey: .thinkingContent)
        showThinking = try container.decode(Bool.self, forKey: .showThinking)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isUser, forKey: .isUser)
        try container.encode(thinkingContent, forKey: .thinkingContent)
        try container.encode(showThinking, forKey: .showThinking)
    }
} 