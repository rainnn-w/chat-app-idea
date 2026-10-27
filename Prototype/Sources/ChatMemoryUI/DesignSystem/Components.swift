import SwiftUI
import ChatMemoryDomain

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(
                cardShape.fill(
                    colorScheme == .dark
                        ? Color.black.opacity(0.42)
                        : ChatTheme.cardBackground
                )
            )
            .overlay(
                cardShape.stroke(
                    colorScheme == .dark ? Color.white.opacity(0.10) : ChatTheme.cardBorder,
                    lineWidth: 1
                )
            )
            .shadow(color: ChatTheme.softShadow, radius: 18, x: 0, y: 10)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

struct PlatformPill: View {
    let platform: ChatPlatform
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: platform.symbolName)
                    .font(.system(size: 11, weight: .bold))
                Text(platform.shortName)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : platform.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? platform.accent : platform.accent.opacity(0.11))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.25) : platform.accent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(platform.displayName)筛选")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct TagChip: View {
    let tag: ChatTag
    let action: (() -> Void)?

    var body: some View {
        let color = ChatTheme.color(for: tag.color)

        Button {
            action?()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tag.symbolName)
                    .font(.system(size: 10, weight: .bold))
                Text(tag.name)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule(style: .continuous).fill(color.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

struct IconBadge: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.13))
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

struct StatPill: View {
    let title: String
    let value: String
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            IconBadge(systemName: symbolName, tint: tint, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(ChatTheme.primaryText)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ChatTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.62))
        )
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ChatTheme.quick, value: configuration.isPressed)
    }
}

