import SwiftUI
import ChatMemoryDomain

extension ChatPlatform {
    var accent: Color {
        ChatTheme.color(for: self)
    }
}

enum ChatTheme {
    static let smooth = Animation.spring(duration: 0.42, bounce: 0.14)
    static let quick = Animation.spring(duration: 0.26, bounce: 0.12)
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.45, blue: 0.54),
            Color(red: 0.72, green: 0.38, blue: 0.94),
            Color(red: 0.25, green: 0.56, blue: 0.98)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let defaultPersonGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.62, blue: 0.62),
            Color(red: 0.70, green: 0.49, blue: 0.96)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let canvasGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.97, green: 0.96, blue: 0.99), location: 0),
            .init(color: Color(red: 0.92, green: 0.94, blue: 0.99), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static func canvasGradient(for colorScheme: ColorScheme) -> LinearGradient {
        switch colorScheme {
        case .light:
            canvasGradient
        case .dark:
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.08, green: 0.07, blue: 0.11), location: 0),
                    .init(color: Color(red: 0.12, green: 0.10, blue: 0.18), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        @unknown default:
            canvasGradient
        }
    }

    static func surface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.075)
            : Color.white.opacity(0.72)
    }

    static let cardBackground = Color.white.opacity(0.72)
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tertiaryText = Color.secondary.opacity(0.75)
    static let cardBorder = Color.black.opacity(0.06)
    static let softShadow = Color.black.opacity(0.08)
    static let disabledGradient = LinearGradient(
        colors: [Color.secondary.opacity(0.35), Color.secondary.opacity(0.35)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func color(for platform: ChatPlatform) -> Color {
        switch platform {
        case .wechat:
            Color(red: 0.16, green: 0.67, blue: 0.40)
        case .qq:
            Color(red: 0.20, green: 0.49, blue: 0.97)
        case .xiaohongshu:
            Color(red: 0.95, green: 0.22, blue: 0.35)
        case .douyin:
            Color(red: 0.08, green: 0.08, blue: 0.12)
        }
    }

    static func color(for tagColor: TagColor) -> Color {
        switch tagColor {
        case .coral:
            Color(red: 0.95, green: 0.40, blue: 0.39)
        case .mint:
            Color(red: 0.06, green: 0.62, blue: 0.51)
        case .lavender:
            Color(red: 0.52, green: 0.38, blue: 0.95)
        case .honey:
            Color(red: 0.91, green: 0.63, blue: 0.19)
        case .sky:
            Color(red: 0.17, green: 0.56, blue: 0.94)
        }
    }

    static func personGradient(for person: ChatPerson) -> LinearGradient {
        switch person.name {
        case "小鹿":
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.57, blue: 0.58),
                    Color(red: 0.65, green: 0.42, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "沐沐":
            LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.80, blue: 0.82),
                    Color(red: 0.31, green: 0.48, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            defaultPersonGradient
        }
    }
}

