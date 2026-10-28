import Foundation

public struct ChatStoreSnapshot: Codable {
    public var people: [ChatPerson]
    public var messages: [ChatMessage]
    public var tags: [ChatTag]
    public var importStatuses: [ImportStatus]
    public var importBatches: [ImportBatch]

    public init(
        people: [ChatPerson],
        messages: [ChatMessage],
        tags: [ChatTag],
        importStatuses: [ImportStatus],
        importBatches: [ImportBatch] = []
    ) {
        self.people = people
        self.messages = messages
        self.tags = tags
        self.importStatuses = importStatuses
        self.importBatches = importBatches
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        people = try container.decode([ChatPerson].self, forKey: .people)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        tags = try container.decode([ChatTag].self, forKey: .tags)
        importStatuses = try container.decode([ImportStatus].self, forKey: .importStatuses)
        importBatches = try container.decodeIfPresent([ImportBatch].self, forKey: .importBatches) ?? []
    }
}

public final class ChatStoreRepository {
    private let fileURL: URL
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.fileManager = .default

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public static func defaultRepository() -> ChatStoreRepository {
        let supportDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("ChatMemory", isDirectory: true)
        ?? URL(fileURLWithPath: "ChatMemory", isDirectory: true)

        return ChatStoreRepository(
            fileURL: supportDirectory.appendingPathComponent("store.json")
        )
    }

    public func load(seed: ChatStore) -> ChatStore {
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try decoder.decode(ChatStoreSnapshot.self, from: data)
            return ChatStore(
                people: snapshot.people,
                messages: snapshot.messages,
                tags: snapshot.tags,
                importStatuses: snapshot.importStatuses,
                importBatches: snapshot.importBatches
            )
        } catch {
            if fileManager.fileExists(atPath: fileURL.path) {
                let backupURL = fileURL.deletingLastPathComponent()
                    .appendingPathComponent("store-corrupt-\(UUID().uuidString).json")
                try? fileManager.copyItem(at: fileURL, to: backupURL)
            }
            return seed
        }
    }

    public func save(_ store: ChatStore) throws {
        let snapshot = ChatStoreSnapshot(
            people: store.people,
            messages: store.messages,
            tags: store.tags,
            importStatuses: store.importStatuses,
            importBatches: store.importBatches
        )

        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func delete() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }
}
