# Ollama Companion

A native macOS application built with SwiftUI that provides a seamless interface for interacting with your local Ollama instance. This companion app makes it easy to manage and interact with your local large language models.

## Features

- 🚀 Native macOS app built with SwiftUI
- 🔄 Real-time interaction with local Ollama instance
- 💻 Clean and intuitive user interface
- 🔒 Secure local-only operations
- ⚡️ High-performance response handling
- 🎨 Modern macOS design patterns

## Requirements

- macOS 14.0 or later
- [Ollama](https://ollama.ai) installed and running locally
- Xcode 15.0+ for development

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/OllamaCompanion.git
```

2. Open the project in Xcode:
```bash
cd OllamaCompanion
open OllamaCompanion.xcodeproj
```

3. Build and run the project (⌘R)

## Configuration

The app connects to your local Ollama instance running at `http://localhost:11434` by default. Make sure Ollama is running before launching the app.

### Default Settings:
- Base URL: http://localhost:11434
- Default Model: llama2
- Context Window: 4096
- Temperature: 0.7
- Max Tokens: 2048

## Architecture

The app follows modern Swift and SwiftUI best practices:

- **MVVM Architecture**: Clear separation of concerns with Views, ViewModels, and Models
- **Swift Concurrency**: Leveraging async/await for smooth performance
- **SwiftUI**: Built with native SwiftUI components for the best macOS experience
- **Combine Framework**: Reactive programming for state management

## Development

### Project Structure
```
OllamaCompanion/
├── Views/          # SwiftUI views
├── ViewModels/     # Business logic and state management
├── Services/       # API and core services
├── Models/         # Data models
└── Assets/         # Resources and assets
```

### Coding Standards

- Swift and SwiftUI best practices
- Comprehensive documentation
- Unit and UI tests
- Modern error handling
- Performance optimizations

## Testing

The project includes:
- Unit Tests
- UI Tests
- Integration Tests

Run tests in Xcode using ⌘U

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Ollama](https://ollama.ai) for providing the amazing local LLM runtime
- The Swift and SwiftUI community for their invaluable resources

## Support

For support, please open an issue in the GitHub repository or contact the maintainers.

---

Made with ❤️ for the Ollama community 