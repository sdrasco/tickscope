import SwiftUI

struct HistoryView: View {
    @Binding var historyTickers: [String]
    var onSelect: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if historyTickers.isEmpty {
                    Text("No recent tickers")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(historyTickers, id: \.self) { ticker in
                        Button {
                            onSelect?(ticker)
                            dismiss()
                        } label: {
                            Label(ticker, systemImage: "clock")
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteTicker(ticker)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
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
            }
        }
    }

    private func deleteTicker(_ ticker: String) {
        if let index = historyTickers.firstIndex(of: ticker) {
            historyTickers.remove(at: index)
            UserDefaults.standard.set(historyTickers, forKey: "historyTickers")
        }
    }
}

#Preview {
    HistoryView(historyTickers: .constant(["AAPL", "MSFT"]))
}

