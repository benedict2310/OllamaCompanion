import SwiftUI
import AppKit

/// Main chat view that displays messages and input field
struct ChatView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel = ChatViewModel()
    @State private var isSidebarVisible = true
    
    // MARK: - Body
    
    var body: some View {
        HSplitView {
            if isSidebarVisible {
                ConversationListView(chatViewModel: viewModel)
            }
            
            VStack(spacing: 0) {
                modelSelector
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                if viewModel.showError {
                    Text(viewModel.errorMessage ?? "Unknown error")
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                
                Divider()
                
                VStack(spacing: 0) {
                    MessagesView(messages: viewModel.messages)
                    
                    MessageInputView(
                        text: $viewModel.inputText,
                        onSend: { content in
                            viewModel.sendMessage(content)
                        },
                        isLoading: viewModel.isProcessing,
                        onStop: {
                            viewModel.stopGeneration()
                        }
                    )
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    isSidebarVisible.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(isSidebarVisible ? "Hide sidebar" : "Show sidebar")
            }
        }
        .frame(minWidth: 400, minHeight: 600)
    }
    
    // MARK: - Private Views
    
    private var modelSelector: some View {
        HStack(spacing: 8) {
            Picker("", selection: $viewModel.selectedModel) {
                if viewModel.availableModels.isEmpty {
                    Text("No models available").tag("none")
                } else {
                    ForEach(viewModel.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }
            .frame(width: 200)
            .disabled(viewModel.availableModels.isEmpty)
            
            Button {
                Task {
                    await viewModel.fetchModels()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(viewModel.isProcessing)
            .help("Refresh available models")
            
            if viewModel.isProcessing {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            }
            
            Spacer()
            
            Button {
                viewModel.startNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .help("Start new conversation")
        }
    }
}

/// Custom view to handle messages display
struct MessagesView: View {
    let messages: [Message]
    @State private var scrolledID: UUID?
    
    var body: some View {
        ScrollViewReader { proxy in
            List(messages) { message in
                MessageBubbleView(message: message)
                    .id(message.id)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .background(Color.clear)
            }
            .listStyle(.plain)
            .background(Color.white)
            .onChange(of: messages) { _, newMessages in
                if let lastMessage = newMessages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView()
} 