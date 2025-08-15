import SwiftUI

struct HistoryView: View {
    @Binding var historyTickers: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(historyTickers, id: \.self) { ticker in
                    Text(ticker)
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("History")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !historyTickers.isEmpty {
                        Button("Clear All") {
                            historyTickers.removeAll()
                            UserDefaults.standard.set(historyTickers, forKey: "historyTickers")
                        }
                    }
                }
#else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    if !historyTickers.isEmpty {
                        Button("Clear All") {
                            historyTickers.removeAll()
                            UserDefaults.standard.set(historyTickers, forKey: "historyTickers")
                        }
                    }
                }
#endif
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        historyTickers.remove(atOffsets: offsets)
        UserDefaults.standard.set(historyTickers, forKey: "historyTickers")
    }
}

#Preview {
    HistoryView(historyTickers: .constant(["AAPL", "MSFT"]))
}

