import Foundation
import Combine
import Darwin

public final class ChatStore: ObservableObject {
    @Published public var people: [ChatPerson]
    @Published public var messages: [ChatMessage]
    @Published public var tags: [ChatTag]
    @Published public var importStatuses: [ImportStatus]
    @Published public var importBatches: [ImportBatch]
    @Published public var selectedPersonID: UUID?
    @Published public var selectedMessageID: UUID?
    @Published public var hoveringMessageID: UUID?
    @Published public var isRefreshing = false
    @Published public var selectedSection: AppSection = .timeline
    @Published public var isShowingCaptureSheet = false
    @Published public var isShowingPersonEditorSheet = false
    @Published public var isShowingMessageEditorSheet = false
    @Published public var isShowingDeleteMessageConfirmation = false
    @Published public var isSelectingRecordFile = false
    @Published public var isSelectingWeChatFolder = false
    @Published public var isShowingJSONImporter = false
    @Published public var isShowingResetConfirmation = false
    @Published public var isShowingSampleConfirmation = false
    @Published public var importError: String?
    @Published public var automationTargetPersonID: UUID?
    @Published public var automationEnabled = true
    @Published public var isAutomationEnabled = true
    @Published public var automationStatus = "待机"
    @Published public var automationLastError: String?
    @Published public var lastInboxImportAt: Date?
    @Published public var inboxPendingCount = 0
    @Published public var searchText = "" {
        didSet { applySearch() }
    }
    @Published public var searchScope: SearchScope = .currentPerson {
        didSet { applySearch() }
    }
    @Published public var selectedPlatforms: Set<ChatPlatform> = Set(ChatPlatform.allCases)
    @Published public private(set) var visibleMessages: [ChatMessage] = []
    public var onDidChange: (() -> Void)?
    private var inboxWatcherSource: DispatchSourceFileSystemObject?
    private var isInboxImportRunning = false
    private var inboxAutomationStarted = false
    private static let automationTargetDefaultsKey = "automationTargetPersonID"
    private static let automationEnabledDefaultsKey = "isInboxAutomationEnabled"

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
        selectedPersonID = people.first?.id
        automationTargetPersonID = selectedPersonID
        automationEnabled = UserDefaults.standard.object(
            forKey: Self.automationEnabledDefaultsKey
        ) as? Bool ?? true

        if let savedTarget = UserDefaults.standard.string(
            forKey: Self.automationTargetDefaultsKey
        ) {
            automationTargetPersonID = UUID(uuidString: savedTarget)
        }

        applySearch()
    }

    public var selectedPerson: ChatPerson? {
        people.first { $0.id == selectedPersonID }
    }

    public var selectedMessage: ChatMessage? {
        messages.first { $0.id == selectedMessageID }
    }

    public var selectedMessages: [ChatMessage] {
        guard let selectedPersonID else { return [] }
        return messages
            .filter { $0.personID == selectedPersonID }
            .sorted { $0.sentAt < $1.sentAt }
    }

    public var tagDictionary: [UUID: ChatTag] {
        Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
    }

    public var personDictionary: [UUID: ChatPerson] {
        Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
    }

    public func select(_ person: ChatPerson?) {
        selectedPersonID = person?.id
        selectedMessageID = nil
        applySearch()
    }

    public func toggle(_ platform: ChatPlatform) {
        if selectedPlatforms.contains(platform), selectedPlatforms.count == 1 {
            selectedPlatforms = Set(ChatPlatform.allCases)
        } else if selectedPlatforms.contains(platform) {
            selectedPlatforms.remove(platform)
        } else {
            selectedPlatforms.insert(platform)
        }
        applySearch()
    }

    public func toggleFavorite(_ message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index].isFavorite.toggle()
        applySearch()
        persist()
    }

    public func toggleTag(_ tag: ChatTag, on message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        if messages[index].tagIDs.contains(tag.id) {
            messages[index].tagIDs.remove(tag.id)
        } else {
            messages[index].tagIDs.insert(tag.id)
        }
        applySearch()
        persist()
    }

    public func addPerson(name: String, subtitle: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let person = ChatPerson(
            name: trimmedName,
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        people.append(person)
        select(person)
        persist()
    }

    public func addMessage(
        personID: UUID? = nil,
        platform: ChatPlatform,
        sender: MessageSender,
        sentAt: Date = Date(),
        text: String,
        externalTitle: String? = nil,
        externalURL: String? = nil,
        tagIDs: Set<UUID> = []
    ) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        guard let targetPersonID = personID ?? selectedPersonID,
              people.contains(where: { $0.id == targetPersonID }) else { return }

        let message = ChatMessage(
            personID: targetPersonID,
            platform: platform,
            sender: sender,
            sentAt: sentAt,
            text: trimmedText,
            externalTitle: externalTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            externalURL: externalURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            tagIDs: tagIDs
        )

        messages.append(message)
        markImported(platform: platform)
        applySearch()
        persist()
    }

    public func updateMessage(_ message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index] = message
        applySearch()
        persist()
    }

    public func deleteMessage(id: UUID) {
        messages.removeAll { $0.id == id }
        if selectedMessageID == id {
            selectedMessageID = nil
        }
        applySearch()
        persist()
    }

    public func replace(with snapshot: ChatStoreSnapshot) {
        people = snapshot.people
        messages = snapshot.messages
        tags = snapshot.tags
        importStatuses = snapshot.importStatuses
        importBatches = snapshot.importBatches
        selectedPersonID = people.first?.id
        selectedMessageID = nil
        selectedPlatforms = Set(ChatPlatform.allCases)
        searchText = ""
        applySearch()
        persist()
    }

    public func makeSnapshot() -> ChatStoreSnapshot {
        ChatStoreSnapshot(
            people: people,
            messages: messages,
            tags: tags,
            importStatuses: importStatuses,
            importBatches: importBatches
        )
    }

    public static var inboxDirectoryURL: URL {
        let supportDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("ChatMemory", isDirectory: true)
        ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatMemory", isDirectory: true)

        return supportDirectory
            .appendingPathComponent("Inbox", isDirectory: true)
    }

    public static var processedDirectoryURL: URL {
        inboxDirectoryURL.appendingPathComponent("Processed", isDirectory: true)
    }

    public static var failedDirectoryURL: URL {
        inboxDirectoryURL.appendingPathComponent("Failed", isDirectory: true)
    }

    public func startInboxAutomation() {
        guard !inboxAutomationStarted else { return }
        guard isAutomationEnabled else {
            automationStatus = "自动导入已关闭"
            return
        }

        inboxAutomationStarted = true
        prepareInbox()
        importInboxFiles()
        startInboxWatcher()
    }

    public func stopInboxAutomation() {
        inboxWatcherSource?.cancel()
        inboxWatcherSource = nil
        automationStatus = "已停止监听"
    }

    public func setAutomationTarget(_ personID: UUID?) {
        automationTargetPersonID = personID
        UserDefaults.standard.set(personID?.uuidString, forKey: Self.automationTargetDefaultsKey)
    }

    public func setAutomationEnabled(_ enabled: Bool) {
        automationEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.automationEnabledDefaultsKey)
        if enabled {
            startInboxAutomation()
        } else {
            stopInboxAutomation()
        }
    }

    public func prepareInbox() {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(
            at: Self.inboxDirectoryURL,
            withIntermediateDirectories: true
        )
        try? fileManager.createDirectory(
            at: Self.processedDirectoryURL,
            withIntermediateDirectories: true
        )
        try? fileManager.createDirectory(
            at: Self.failedDirectoryURL,
            withIntermediateDirectories: true
        )
        refreshInboxPendingCount()
    }

    public func importInboxFiles() {
        guard isAutomationEnabled, !isInboxImportRunning else { return }
        isInboxImportRunning = true
        automationStatus = "正在检查 Inbox"
        prepareInbox()

        let supportedExtensions: Set<String> = [
            "json", "ndjson", "html", "htm", "mht", "mhtml",
            "db", "sqlite", "sqlite3", "db3"
        ]
        let fileManager = FileManager.default
        var reports: [String] = []

        let files = ((try? fileManager.contentsOfDirectory(
            at: Self.inboxDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { url in
                supportedExtensions.contains(url.pathExtension.lowercased())
            }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return lhsDate < rhsDate
            }

        if files.isEmpty {
            inboxPendingCount = 0
            automationStatus = "Inbox 已是最新"
            isInboxImportRunning = false
            return
        }

        inboxPendingCount = files.count

        for fileURL in files {
            automationStatus = "正在导入 \(fileURL.lastPathComponent)"

            do {
                let data = try Data(contentsOf: fileURL)
                let output = try RealChatImporter().parse(data: data, url: fileURL)

                guard let personID = automationTargetPersonID ?? selectedPersonID else {
                    throw ImportError(message: "还没有设置自动导入联系人。")
                }

                guard importRealRecords(
                    output.records,
                    personID: personID,
                    fileName: fileURL.lastPathComponent,
                    format: output.format,
                    now: Date()
                ) != nil else {
                    throw ImportError(message: "没有可用的导入联系人。")
                }

                try moveInboxFile(fileURL, to: Self.processedDirectoryURL)
                reports.append("✅ \(fileURL.lastPathComponent)：导入 \(output.records.count) 条")
            } catch {
                let message = error.localizedDescription
                automationLastError = message
                reports.append("❌ \(fileURL.lastPathComponent)：\(message)")
                try? moveInboxFile(fileURL, to: Self.failedDirectoryURL)
            }
        }

        lastInboxImportAt = Date()
        inboxPendingCount = 0
        automationStatus = reports.joined(separator: "\n")
        isInboxImportRunning = false
        refreshInboxPendingCount()
    }

    public func refreshInboxPendingCount() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: Self.inboxDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        inboxPendingCount = files.count
    }

    private func startInboxWatcher() {
        guard inboxWatcherSource == nil else { return }

        let path = Self.inboxDirectoryURL.path
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else {
            automationLastError = "无法监听 Inbox 目录。"
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.importInboxFiles()
            }
        }

        source.setCancelHandler {
            close(descriptor)
        }

        source.resume()
        inboxWatcherSource = source
        automationStatus = "正在监听 Inbox"
    }

    private func moveInboxFile(_ source: URL, to directory: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let destination = directory.appendingPathComponent(
            "\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)-\(source.lastPathComponent)"
        )

        try fileManager.moveItem(at: source, to: destination)
        refreshInboxPendingCount()
    }

    @discardableResult
    public func importRealRecords(
        _ records: [RawImportRecord],
        personID: UUID? = nil,
        fileName: String,
        format: ImportFormat,
        now: Date = Date()
    ) -> ImportBatch? {
        guard let targetPersonID = personID ?? selectedPersonID,
              people.contains(where: { $0.id == targetPersonID }) else { return nil }

        let batchID = UUID()
        var imported = 0
        var skipped = 0
        var warnings: [String] = []
        var signatures = Set(messages.compactMap(\.sourceIdentifier))
        var legacySignatures = Set(messages.map(\.dedupSignature))

        for record in records {
            let normalizedText = record.text
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedText.isEmpty else {
                skipped += 1
                continue
            }

            let sourceIdentifier = record.sourceIdentifier
            let signature = record.dedupSignature
            if signatures.contains(sourceIdentifier) || legacySignatures.contains(signature) {
                skipped += 1
                continue
            }

            let message = record.makeMessage(
                personID: targetPersonID,
                batchID: batchID
            )
            messages.append(message)
            signatures.insert(sourceIdentifier)
            legacySignatures.insert(signature)
            imported += 1
        }

        let usedPlatforms = Set(records.map(\.platform))
        usedPlatforms.forEach { markImported(platform: $0, at: now) }

        if records.isEmpty {
            warnings.append("没有解析到可导入的消息。")
        }
        if skipped > 0 {
            warnings.append("跳过 \(skipped) 条重复或空白消息。")
        }

        let batch = ImportBatch(
            id: batchID,
            fileName: fileName,
            format: format,
            importedCount: imported,
            skippedCount: skipped,
            importedAt: now,
            warnings: warnings
        )
        importBatches.append(batch)
        applySearch()
        persist()
        return batch
    }

    public func markImported(platform: ChatPlatform, at date: Date = Date()) {
        if let index = importStatuses.firstIndex(where: { $0.platform == platform }) {
            importStatuses[index].lastUpdated = date
            importStatuses[index].state = .fresh
        } else {
            importStatuses.append(
                ImportStatus(platform: platform, lastUpdated: date, state: .fresh)
            )
        }
    }

    public func messageTags(for message: ChatMessage) -> [ChatTag] {
        message.tagIDs.compactMap { tagDictionary[$0] }.sorted { $0.name < $1.name }
    }

    public func groupedVisibleMessages(calendar: Calendar = .current) -> [(day: Date, messages: [ChatMessage])] {
        let groups = Dictionary(grouping: visibleMessages) { calendar.startOfDay(for: $0.sentAt) }
        return groups
            .map { (day: $0.key, messages: $0.value.sorted { $0.sentAt < $1.sentAt }) }
            .sorted { $0.day < $1.day }
    }

    public func applySearch() {
        let query = SearchQuery.parse(searchText)
        let queryPlatforms = query.platforms
        let platforms = selectedPlatforms
        let personID = selectedPersonID
        let selectedPeople = searchScope == .currentPerson
            ? people.filter { $0.id == personID }
            : people
        let peopleByID = personDictionary
        let tagsByID = tagDictionary

        visibleMessages = messages
            .filter { message in
                guard let person = peopleByID[message.personID] else { return false }
                return selectedPeople.contains { $0.id == person.id }
            }
            .filter { platforms.contains($0.platform) }
            .filter { queryPlatforms.isEmpty || queryPlatforms.contains($0.platform) }
            .filter { message in
                let tagNames = message.tagIDs
                    .compactMap { tagsByID[$0]?.name }
                return query.matches(
                    message: message,
                    person: peopleByID[message.personID],
                    tagNames: tagNames
                )
            }
            .sorted { $0.sentAt > $1.sentAt }
    }

    private func persist() {
        onDidChange?()
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

