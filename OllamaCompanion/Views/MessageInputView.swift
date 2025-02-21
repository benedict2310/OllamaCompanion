import SwiftUI
import AppKit

/// Input view for typing and sending messages
struct MessageInputView: View {
    // MARK: - Properties
    
    @Binding var text: String
    @FocusState private var isFocused: Bool
    let onSend: (String) -> Void
    let isLoading: Bool
    let onStop: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("Type a message...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(height: 36)
                .focused($isFocused)
                .onSubmit {
                    handleSendMessage()
                }
                .onChange(of: isLoading) { _, newValue in
                    if !newValue {
                        isFocused = true
                    }
                }
                .disabled(isLoading)
            
            Button(action: isLoading ? onStop : handleSendMessage) {
                if isLoading {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading)
            .help(isLoading ? "Stop generating" : "Send message")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .top
        )
        .onAppear {
            isFocused = true
        }
    }
    
    // MARK: - Private Methods
    
    private func handleSendMessage() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty && !isLoading else { return }
        
        let textToSend = trimmedText
        
        DispatchQueue.main.async {
            text = ""
        }
        
        onSend(textToSend)
        isFocused = true
    }
} 