import SwiftUI
import ChatMemoryDomain

struct PersonEditorView: View {
    @ObservedObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var model = PersonEditorModel()
    @FocusState private var nameFocused: Bool

    final class PersonEditorModel: ObservableObject {
        @Published var name = ""
        @Published var subtitle = ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                IconBadge(systemName: "person.crop.circle.badge.plus", tint: .pink, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("添加联系人")
                        .font(.system(size: 21, weight: .heavy))
                    Text("先创建一个人物，再绑定平台身份")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ChatTheme.secondaryText)
                }
                Spacer()
            }

            GlassCard(cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("称呼")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ChatTheme.secondaryText)
                        TextField("例如：小鹿", text: $model.name)
                            .textFieldStyle(.plain)
                            .focused($nameFocused)
                            .padding(11)
                            .background(fieldBackground)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("平台备注")
                        TextField("微信 · 小红书 · 抖音", text: $model.subtitle)
                            .textFieldStyle(.plain)
                            .padding(11)
                            .background(fieldBackground)
                    }
                }
                .padding(15)
            }

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    store.addPerson(name: model.name, subtitle: model.subtitle)
                    dismiss()
                } label: {
                    Label("创建", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(Capsule(style: .continuous).fill(ChatTheme.heroGradient))
                }
                .buttonStyle(PressableButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 430)
        .background(ChatTheme.canvasGradient(for: colorScheme))
        .onAppear { nameFocused = true }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(ChatTheme.surface(for: colorScheme))
            .stroke(Color.black.opacity(0.05), lineWidth: 1)
    }
}

