import SwiftUI

struct NightscoutHeaderView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            switch store.nightscoutState {
            case .idle:
                EmptyView()
            case .loading:
                banner(icon: "arrow.triangle.2.circlepath", text: "Actualizando glucosa...", color: .secondary)
            case .error:
                banner(icon: "exclamationmark.triangle", text: "Error de Nightscout", color: .red)
            case .success(let entry):
                let arrow = NightscoutService.trendArrow(entry.direction)
                banner(icon: "drop.fill", text: "\(entry.sgv) mg/dL \(arrow)", color: .teal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func banner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.footnote)
                .foregroundStyle(color)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
