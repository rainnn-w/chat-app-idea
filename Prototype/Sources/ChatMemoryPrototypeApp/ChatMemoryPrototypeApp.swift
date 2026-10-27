import SwiftUI
import ChatMemoryUI

@main
struct ChatMemoryPrototypeApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .frame(minWidth: 880, minHeight: 620)
        }
        .windowStyle(.automatic)
    }
}

