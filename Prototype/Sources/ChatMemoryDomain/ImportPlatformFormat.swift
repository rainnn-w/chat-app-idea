import Foundation

extension ChatPlatform {
    var importFormat: ImportFormat {
        switch self {
        case .xiaohongshu: .xiaohongshuExport
        case .douyin: .douyinExport
        case .qq: .qqHTMLArchive
        case .wechat: .genericJSON
        }
    }

    var chatLabFallbackPlatform: ChatPlatform {
        switch self {
        case .xiaohongshu: .xiaohongshu
        case .qq: .qq
        default: .wechat
        }
    }
}

extension RealChatImporter {
    func exportFormat(for platform: ChatPlatform) -> ImportFormat {
        platform.importFormat
    }
}
