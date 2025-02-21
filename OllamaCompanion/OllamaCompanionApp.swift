//
//  OllamaCompanionApp.swift
//  OllamaCompanion
//
//  Created by Benedict Bleimschein on 18.02.25.
//

import SwiftUI

@main
struct OllamaCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
                .frame(minWidth: 400, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
