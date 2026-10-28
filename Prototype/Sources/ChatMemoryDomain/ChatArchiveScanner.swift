import Foundation

public struct DiscoveredChatArchive: Identifiable, Hashable {
    public var id: String
    public var url: URL
    public var platform: ChatPlatform
    public var format: ImportFormat
    public var fileName: String
    public var relativePath: String
    public var sizeBytes: Int64
    public var modifiedAt: Date
    public var reason: String

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

public struct ChatArchiveScanResult: Hashable {
    public var archives: [DiscoveredChatArchive]
    public var scannedDirectories: Int
    public var unreadableDirectories: [String]
    public var warnings: [String]

    public var hasResults: Bool {
        !archives.isEmpty
    }
}

public struct ChatArchiveScanner {
    private let fileManager: FileManager
    private let maximumDepth: Int

    public init(fileManager: FileManager = .default, maximumDepth: Int = 10) {
        self.fileManager = fileManager
        self.maximumDepth = maximumDepth
    }

    public func scanWeChatLocations() -> ChatArchiveScanResult {
        let home = fileManager.homeDirectoryForCurrentUser
        let roots: [URL] = [
            home.appendingPathComponent("Library/Containers/com.tencent.xinWeChat", isDirectory: true),
            home.appendingPathComponent("Library/Application Support/com.tencent.xinWeChat", isDirectory: true),
            home.appendingPathComponent("Library/Group Containers/group.com.tencent.xinWeChat", isDirectory: true),
            home.appendingPathComponent("Documents/WeChat Files", isDirectory: true)
        ]

        return scanDirectories(at: roots, platform: .wechat, format: .wechatSQLite)
    }

    public func scanDirectories(
        at roots: [URL],
        platform: ChatPlatform,
        format: ImportFormat
    ) -> ChatArchiveScanResult {
        var archives: [DiscoveredChatArchive] = []
        var scannedDirectories = 0
        var unreadableDirectories: [String] = []
        var warnings: [String] = []
        let databaseExtensions: Set<String> = ["db", "sqlite", "sqlite3", "db3"]
        let skippedDirectoryNames: Set<String> = [
            "Caches",
            "cache",
            "Logs",
            "tmp",
            "TemporaryItems",
            ".Trash"
        ]

        for root in roots {
            let root = root.standardizedFileURL
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            guard fileManager.isReadableFile(atPath: root.path) else {
                unreadableDirectories.append(root.path)
                continue
            }

            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .isRegularFileKey
                ],
                options: [.producesRelativePathURLs],
                errorHandler: { _, error in
                    warnings.append(error.localizedDescription)
                    return true
                }
            ) else {
                unreadableDirectories.append(root.path)
                continue
            }

            var currentDepth = 0
            var lastDirectoryPath = ""

            for case let fileURL as URL in enumerator {
                let path = fileURL.standardizedFileURL.path

                if path.count != lastDirectoryPath.count {
                    currentDepth = path.components(separatedBy: "/").count
                        - root.path.components(separatedBy: "/").count
                    lastDirectoryPath = path
                }

                if currentDepth > maximumDepth {
                    enumerator.skipDescendants()
                    continue
                }

                do {
                    let values = try fileURL.resourceValues(forKeys: [
                        .isDirectoryKey,
                        .isRegularFileKey,
                        .fileSizeKey,
                        .contentModificationDateKey
                    ])

                    if values.isDirectory == true {
                        scannedDirectories += 1
                        let name = fileURL.lastPathComponent
                        if skippedDirectoryNames.contains(name) {
                            enumerator.skipDescendants()
                        }
                        continue
                    }

                    guard values.isRegularFile == true,
                          databaseExtensions.contains(fileURL.pathExtension.lowercased()),
                          let size = values.fileSize, size > 0 else {
                        continue
                    }

                    let relativePath = path
                        .replacingOccurrences(of: root.path + "/", with: "")
                    let reason: String
                    if relativePath.contains("/Message/") || relativePath.hasPrefix("Message/") {
                        reason = "微信 Message 目录"
                    } else if relativePath.lowercased().contains("message") {
                        reason = "消息相关目录"
                    } else {
                        reason = "候选 SQLite 数据库"
                    }

                    archives.append(
                        DiscoveredChatArchive(
                            id: path,
                            url: fileURL,
                            platform: platform,
                            format: format,
                            fileName: fileURL.lastPathComponent,
                            relativePath: relativePath,
                            sizeBytes: Int64(size),
                            modifiedAt: values.contentModificationDate ?? .distantPast,
                            reason: reason
                        )
                    )
                } catch {
                    warnings.append("\(path)：\(error.localizedDescription)")
                }
            }
        }

        if archives.isEmpty {
            warnings.append("没有在常见微信目录中发现 SQLite 数据库。")
        }
        if !unreadableDirectories.isEmpty {
            warnings.append("有 \(unreadableDirectories.count) 个目录没有读取权限。")
        }

        return ChatArchiveScanResult(
            archives: archives.sorted { $0.modifiedAt > $1.modifiedAt },
            scannedDirectories: scannedDirectories,
            unreadableDirectories: unreadableDirectories,
            warnings: Array(warnings.prefix(5))
        )
    }
}

