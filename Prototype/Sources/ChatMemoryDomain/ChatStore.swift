import Foundation
import Combine

public final class ChatStore: ObservableObject {
    @Published public var people: [ChatPerson]
    @Published public var messages: [ChatMessage]
    @Published public var tags: [ChatTag]
    @Published public var importStatuses: [ImportStatus]
    @Published public var selectedPersonID: UUID?
    @Published public var selectedMessageID: UUID?
    @Published public var hoveringMessageID: UUID?
    @Published public var isRefreshing = false
    @Published public var selectedSection: AppSection = .timeline
    @Published public var isShowingCaptureSheet = false
    @Published public var isShowingPersonEditorSheet = false
    @Published public var isShowingMessageEditorSheet = false
    @Published public var isShowingDeleteMessageConfirmation = false
    @Published public var isShowingJSONImporter = false
    @Published public var isShowingResetConfirmation = false
    @Published public var isShowingSampleConfirmation = false
    @Published public var importError: String?
    @Published public var searchText = "" {
        didSet { applySearch() }
    }
    @Published public var searchScope: SearchScope = .currentPerson {
        didSet { applySearch() }
    }
    @Published public var selectedPlatforms: Set<ChatPlatform> = Set(ChatPlatform.allCases)
    @Published public private(set) var visibleMessages: [ChatMessage] = []
    public var onDidChange: (() -> Void)?

    public init(
        people: [ChatPerson],
        messages: [ChatMessage],
        tags: [ChatTag],
        importStatuses: [ImportStatus]
    ) {
        self.people = people
        self.messages = messages
        self.tags = tags
        self.importStatuses = importStatuses
        selectedPersonID = people.first?.id
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
            importStatuses: importStatuses
        )
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

