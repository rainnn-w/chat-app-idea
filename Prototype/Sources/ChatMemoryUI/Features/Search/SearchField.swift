import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var prompt = "搜索 香菜 / tag:约定 / person:小鹿 / is:favorite"
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ChatTheme.tertiaryText)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .focused($isFocused)
                .onSubmit { isFocused = false }

            if !text.isEmpty {
                Button {
                    withAnimation(ChatTheme.quick) {
                        text = ""
                        isFocused = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(ChatTheme.tertiaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ChatTheme.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ChatTheme.heroGradient, lineWidth: 1.5)
                .opacity(isFocused ? 1 : 0)
        )
        .shadow(color: ChatTheme.softShadow, radius: 12, x: 0, y: 6)
    }
}

