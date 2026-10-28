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
}

extension RealChatImporter {
    func exportFormat(for platform: ChatPlatform) -> ImportFormat {
        platform.importFormat
    }
}
