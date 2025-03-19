import SwiftUI

@main
struct tickscopeApp: App {
    @State private var needsAPIKey = KeychainManager.getAPIKey() == nil

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $needsAPIKey) {
                    APIKeyPromptView(isPresented: $needsAPIKey)
                }
        }
    }
}
