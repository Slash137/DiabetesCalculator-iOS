import SwiftUI

struct MedicalNoticeView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "cross.case")
                .foregroundStyle(.orange)
            Text("Esta app es una ayuda y no sustituye el criterio medico profesional.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
