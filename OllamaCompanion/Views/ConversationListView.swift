import SwiftUI

/// Displays a list of saved conversations
struct ConversationListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject private var store = ConversationStore.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Conversations")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Conversation List
            if store.conversations.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No conversations yet")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(store.conversations) { conversation in
                    ConversationRow(conversation: conversation)
                        .onTapGesture {
                            chatViewModel.loadConversation(conversation)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    store.deleteConversation(conversation)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                // Copy conversation title to clipboard
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(conversation.title, forType: .string)
                            } label: {
                                Label("Copy Title", systemImage: "doc.on.doc")
                            }
                            .tint(.blue)
                        }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 250)
        .background(Color(nsColor: colorScheme == .dark ? .windowBackgroundColor : .white))
    }
}

/// Displays a single conversation in the list
private struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .lineLimit(2)
                .font(.headline)
            
            HStack {
                Text(conversation.model)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(conversation.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
} 