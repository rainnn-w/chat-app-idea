import Foundation

public enum ChatPlatform: String, CaseIterable, Codable, Hashable, Identifiable {
    case wechat
    case qq
    case xiaohongshu
    case douyin

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .wechat: "微信"
        case .qq: "QQ"
        case .xiaohongshu: "小红书"
        case .douyin: "抖音"
        }
    }

    public var shortName: String {
        switch self {
        case .xiaohongshu: "红书"
        case .douyin: "抖音"
        case .wechat: "微信"
        case .qq: "QQ"
        }
    }

    public var symbolName: String {
        switch self {
        case .wechat: "message.fill"
        case .qq: "bubble.left.and.bubble.right.fill"
        case .xiaohongshu: "book.fill"
        case .douyin: "music.note.list"
        }
    }

}

public enum MessageSender: String, CaseIterable, Codable, Hashable {
    case me
    case peer
    case system

    public var displayName: String {
        switch self {
        case .me: "我"
        case .peer: "对方"
        case .system: "系统"
        }
    }
}

public struct ChatPerson: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var subtitle: String
    public var initials: String

    public init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        initials: String? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.initials = initials ?? String(name.prefix(1))
    }
}

public struct ChatTag: Identifiable, Hashable, Codable {
    public var id: UUID
    public var name: String
    public var symbolName: String
    public var color: TagColor

    public init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        color: TagColor
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.color = color
    }
}

public enum TagColor: String, CaseIterable, Codable, Hashable {
    case coral
    case mint
    case lavender
    case honey
    case sky
}

public enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case timeline
    case tags
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .timeline: "时间线"
        case .tags: "标签"
        case .settings: "设置"
        }
    }

    public var symbolName: String {
        switch self {
        case .timeline: "bubble.left.and.bubble.right.fill"
        case .tags: "tag.fill"
        case .settings: "gearshape.fill"
        }
    }
}

public struct ChatMessage: Identifiable, Hashable, Codable {
    public var id: UUID
    public var personID: UUID
    public var platform: ChatPlatform
    public var sender: MessageSender
    public var sentAt: Date
    public var text: String
    public var externalTitle: String?
    public var externalURL: String?
    public var tagIDs: Set<UUID>
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        personID: UUID,
        platform: ChatPlatform,
        sender: MessageSender,
        sentAt: Date,
        text: String,
        externalTitle: String? = nil,
        externalURL: String? = nil,
        tagIDs: Set<UUID> = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.personID = personID
        self.platform = platform
        self.sender = sender
        self.sentAt = sentAt
        self.text = text
        self.externalTitle = externalTitle
        self.externalURL = externalURL
        self.tagIDs = tagIDs
        self.isFavorite = isFavorite
    }
}

public struct ImportStatus: Hashable, Codable {
    public var platform: ChatPlatform
    public var lastUpdated: Date
    public var state: State

    public init(
        platform: ChatPlatform,
        lastUpdated: Date,
        state: State
    ) {
        self.platform = platform
        self.lastUpdated = lastUpdated
        self.state = state
    }

    public enum State: String, Codable, Hashable {
        case fresh
        case stale
        case needsAttention

        public var title: String {
            switch self {
            case .fresh: "已更新"
            case .stale: "待更新"
            case .needsAttention: "需处理"
            }
        }
    }
}

