import SwiftUI

/// Animated typing indicator with three dots
private struct TypingIndicator: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == index ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 0.15), value: phase)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

/// Displays a single message in a chat bubble
struct MessageBubbleView: View {
    // MARK: - Properties
    
    @State private var isThinkingExpanded: Bool = false
    let message: Message
    
    private var backgroundColor: Color {
        message.isUser ? Color.blue : Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    }
    
    private var foregroundColor: Color {
        message.isUser ? .white : .primary
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if let thinking = message.thinkingContent {
                    DisclosureGroup(
                        isExpanded: .init(
                            get: { isThinkingExpanded },
                            set: { 
                                isThinkingExpanded = $0
                                message.showThinking = $0
                            }
                        ),
                        content: {
                            Text(thinking)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                                .textSelection(.enabled)
                        },
                        label: {
                            Label("Thinking Process", systemImage: "brain")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
                    .padding(.bottom, 4)
                }
                
                if message.isUser {
                    Text(message.content)
                } else if message.content.isEmpty {
                    TypingIndicator()
                } else {
                    MessageContentView(content: message.content)
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
                    .if(!message.isUser) { view in
                        view.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    }
            )
            .contextMenu {
                if message.thinkingContent != nil {
                    Button(isThinkingExpanded ? "Hide Thinking" : "Show Thinking") {
                        isThinkingExpanded.toggle()
                        message.showThinking = isThinkingExpanded
                    }
                    Divider()
                }
                Button("Copy") {
                    var textToCopy = message.content
                    if let thinking = message.thinkingContent, message.showThinking {
                        textToCopy = "<think>\n\(thinking)\n</think>\n\n\(textToCopy)"
                    }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToCopy, forType: .string)
                }
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .onAppear {
            isThinkingExpanded = message.showThinking
        }
    }
}

struct MessageContentView: View {
    let content: String
    
    var body: some View {
        let processedContent = processMarkdown(content)
        
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(processedContent.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                if line.hasPrefix("### ") {
                    Text(line.replacingOccurrences(of: "### ", with: ""))
                        .font(.system(size: 20, weight: .bold))
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                } else if line.hasPrefix("#### ") {
                    Text(line.replacingOccurrences(of: "#### ", with: ""))
                        .font(.system(size: 16, weight: .bold))
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                } else if line.hasPrefix("• ") {
                    HStack(alignment: .top) {
                        Text("•")
                            .font(.system(size: 14))
                            .padding(.top, 2)
                        Text(line.replacingOccurrences(of: "• ", with: ""))
                    }
                    .padding(.leading, 8)
                } else if line.isEmpty {
                    Spacer()
                        .frame(height: 8)
                } else {
                    Text(.init(line))
                }
            }
        }
        .textSelection(.enabled)
    }
    
    private func processMarkdown(_ text: String) -> String {
        var processedText = text
        
        // Process headers with proper spacing
        processedText = processedText.replacingOccurrences(
            of: #"###\s+\*\*(.*?)\*\*"#,
            with: "### $1",
            options: .regularExpression
        )
        
        // Process subheaders
        processedText = processedText.replacingOccurrences(
            of: #"####\s+(.*?)(?:\n|$)"#,
            with: "#### $1\n",
            options: .regularExpression
        )
        
        // Process list items with proper indentation
        processedText = processedText.replacingOccurrences(
            of: #"\n-\s+"#,
            with: "\n• ",
            options: .regularExpression
        )
        
        // Process numbered list items
        processedText = processedText.replacingOccurrences(
            of: #"\n(\d+)\.\s+"#,
            with: "\n$1. ",
            options: .regularExpression
        )
        
        // Process horizontal rules with proper spacing
        processedText = processedText.replacingOccurrences(
            of: "\n---\n",
            with: "\n\n---\n\n"
        )
        
        // Clean up multiple newlines
        processedText = processedText.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        
        return processedText
    }
}

// MARK: - View Extension

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        MessageBubbleView(message: Message(content: "Hello, how are you?", isUser: true))
        MessageBubbleView(message: Message(content: """
            ### 4. Nutrition and Hydration
            - **Balanced Diet:** Focus on a diet rich in carbohydrates, proteins, and healthy fats. Carb-load before the race.
            - **Hydration:** Use electrolytes during runs longer than 90 minutes to maintain performance.

            ### 5. Sleep and Recovery
            - Ensure 7-9 hours of sleep nightly for muscle repair and recovery. Establish a bedtime routine if necessary.

            ### 6. Tapering Strategy
            - Reduce mileage by 30-50% in the final weeks before the race to allow glycogen storage and recovery.
            """, isUser: false))
    }
    .padding()
} 