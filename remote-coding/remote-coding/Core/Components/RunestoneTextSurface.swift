import SwiftUI

struct RunestoneTextSurface: View {
    @Binding var text: String

    let isEditable: Bool

    var body: some View {
        TextEditor(text: editableBinding)
            .font(.system(.body, design: .monospaced))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .scrollContentBackground(.hidden)
            .background(Color(.secondarySystemBackground))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(isEditable ? "Start writing..." : "")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
            }
    }

    private var editableBinding: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                if isEditable {
                    text = newValue
                }
            }
        )
    }
}

