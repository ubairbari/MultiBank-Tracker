import SwiftUI

// MARK:  -  Change Indicator  -  
struct ChangeLabel: View {
    let change: Double
    var body: some View {
        let positive = change >= 0
        Label {
            Text("\(positive ? "+" : "")\(change, format: .currency(code: "USD"))")
        } icon: {
            Image(systemName: positive ? "arrow.up.right" : "arrow.down.right")
        }
        .font(.caption.weight(.medium).monospacedDigit())
        .foregroundStyle(positive ? .green : .red)
        .accessibilityLabel("Price change \(positive ? "up" : "down") \(abs(change), format: .currency(code: "USD"))")
    }
}
