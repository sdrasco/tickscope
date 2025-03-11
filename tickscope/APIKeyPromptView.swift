import SwiftUI

struct APIKeyPromptView: View {
    @State private var apiKey: String = ""
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            Text("Enter API Key")
                .font(.title2)
                .padding()

            SecureField("API Key", text: $apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 250)
                .padding()

            Button("Save") {
                KeychainManager.saveAPIKey(apiKey)
                isPresented = false  // Close the prompt
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}
