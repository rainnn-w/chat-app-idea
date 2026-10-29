import SwiftUI
import ChatMemoryDomain
import UniformTypeIdentifiers

struct MessageCaptureView: View {
    @ObservedObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var model = MessageCaptureModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Picker("录入方式", selection: $model.mode) {
                ForEach(MessageCaptureModel.CaptureMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            GlassCard(cornerRadius: 21) {
                VStack(alignment: .leading, spacing: 15) {
                    if model.mode == .single {
                        singleForm
                    } else {
                        realFileForm
                    }
                }
                .padding(15)
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
            }

            HStack {
                Text("数据会保存在本机")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ChatTheme.tertiaryText)
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                saveButton
            }
        }
        .padding(20)
        .frame(width: 620, height: model.mode == .single ? 590 : (model.scanResult?.hasResults == true ? 820 : 700))
        .background(ChatTheme.canvasGradient(for: colorScheme))
        .animation(ChatTheme.smooth, value: model.mode)
        .fileImporter(
            isPresented: $store.isSelectingRecordFile,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            model.selectFile(from: result)
        }
        .fileImporter(
            isPresented: $store.isSelectingWeChatFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            model.selectScanFolder(from: result)
        }
        .fileImporter(
            isPresented: $store.isSelectingDecryptedWeChatDirectory,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            model.importDecryptedWechatDirectory(from: result, store: store)
        }
        .onDisappear {
            model.releaseScanFolderAccess()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            IconBadge(
                systemName: model.mode == .single ? "plus.square.dashed.on.square" : "shippingbox.fill",
                tint: .purple,
                size: 40
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("录入聊天记忆")
                    .font(.system(size: 21, weight: .heavy))
                Text(store.selectedPerson.map { "当前联系人：\($0.name)" } ?? "请先选择联系人")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ChatTheme.secondaryText)
            }
            Spacer()
        }
    }

    private var singleForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            platformPicker
            senderPicker(allowSystem: true)

            DatePicker("时间", selection: $model.sentAt)
                .datePickerStyle(.compact)

            LabeledEditor(title: "内容", text: $model.text, minHeight: 105)

            HStack(spacing: 10) {
                captionField("原帖标题", text: $model.externalTitle, prompt: "京都咖啡地图")
                captionField("原帖链接", text: $model.externalURL, prompt: "https://")
            }

            tagPicker
        }
    }

    private var realFileForm: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 10) {
                Button {
                    store.isSelectingRecordFile = true
                } label: {
                    Label(model.selectedFileName == nil ? "选择记录文件" : "更换文件", systemImage: "folder.badge.plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule(style: .continuous).fill(ChatTheme.heroGradient))
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    Task { await model.scanWeChatLocations() }
                } label: {
                    Label("自动扫描微信", systemImage: "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule(style: .continuous).fill(Color.blue))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(model.isScanningArchives)

                Button {
                    store.isSelectingWeChatFolder = true
                } label: {
                    Label("选择微信目录", systemImage: "folder")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous).fill(Color.blue.opacity(0.10))
                        )
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(model.isScanningArchives)

                Button {
                    store.isSelectingDecryptedWeChatDirectory = true
                } label: {
                    Label("解密后的微信目录", systemImage: "lock.open.application")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule(style: .continuous).fill(Color.green))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(model.isProcessing)

                if model.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }

            if model.isScanningArchives {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在扫描常见微信目录…")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ChatTheme.secondaryText)
                }
            }

            if let scanResult = model.scanResult {
                candidateList(scanResult)
            }

            if let fileName = model.selectedFileName {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.badge.gearshape.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.purple)
                        Text(fileName)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    if let format = model.detectedFormat {
                        Label(format.title, systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                    }

                    Text(model.detectedFormat?.guidance ?? "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ChatTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.purple.opacity(0.08))
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("支持真实来源数据")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(ChatTheme.primaryText)

                    supportedFormatRow("微信", "Message/*.db SQLite")
                    supportedFormatRow("QQ", ".mht / .html 网页归档")
                    supportedFormatRow("小红书", "账号导出 JSON / NDJSON / HTML")
                    supportedFormatRow("抖音", "账号导出 JSON / NDJSON / HTML")
                    supportedFormatRow("QQ / 小红书", "ChatLab JSON / JSONL")
                    supportedFormatRow("抖音", "数据导出 JSON")
                    supportedFormatRow("微信", "WeChatDataAnalysis messages.json / 导出目录")
                    supportedFormatRow("通用", "messages / data / items / records JSON")
                }
            }

            if let output = model.importOutput {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Label("解析到 \(output.records.count) 条消息", systemImage: "tray.full.fill")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.green)
                        Spacer()
                    }

                    ForEach(output.records.prefix(3)) { record in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(record.platform.displayName) · \(record.sender.displayName)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(record.platform.accent)
                            Text(record.text)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(ChatTheme.secondaryText)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }

                    if output.records.count > 3 {
                        Text("还有 \(output.records.count - 3) 条…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ChatTheme.tertiaryText)
                    }

                    ForEach(output.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.green.opacity(0.08))
                )
            }

            if let summary = model.importSummary {
                Text(summary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func candidateList(_ result: ChatArchiveScanResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    result.hasResults ? "发现 \(result.archives.count) 个候选数据库" : "未发现候选数据库",
                    systemImage: result.hasResults ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                )
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(result.hasResults ? .green : .orange)

                Spacer()
                Text("已扫描 \(result.scannedDirectories) 个目录")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ChatTheme.tertiaryText)
            }

            ScrollView {
                VStack(spacing: 7) {
                    ForEach(result.archives) { archive in
                        Button {
                            model.select(archive)
                        } label: {
                            HStack(spacing: 10) {
                                IconBadge(
                                    systemName: "cylinder.split.1x2.fill",
                                    tint: archive.isEncrypted
                                        ? .red
                                        : model.selectedArchiveID == archive.id ? .purple : .green,
                                    size: 32
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(archive.fileName)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(ChatTheme.primaryText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text(archive.relativePath)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(ChatTheme.tertiaryText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(archive.formattedSize)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                    Text(archive.reason)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(ChatTheme.tertiaryText)
                                    if archive.isEncrypted {
                                        Text("已加密")
                                            .font(.system(size: 10, weight: .heavy))
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            .padding(9)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        model.selectedArchiveID == archive.id
                                            ? Color.purple.opacity(0.12)
                                            : ChatTheme.surface(for: colorScheme)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        model.selectedArchiveID == archive.id
                                            ? Color.purple.opacity(0.25)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(archive.isEncrypted)
                    }
                }
            }
            .frame(maxHeight: 165)

            ForEach(result.warnings, id: \.self) { warning in
                Label(warning, systemImage: "info.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.blue.opacity(0.06))
        )
    }

    private var saveButton: some View {
        Button {
            model.save(to: store)
            dismiss()
        } label: {
            Label("导入并保存", systemImage: "tray.and.arrow.down.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(model.canSave ? ChatTheme.heroGradient : ChatTheme.disabledGradient)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .keyboardShortcut(.defaultAction)
        .disabled(!model.canSave)
    }

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("标签")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.tags) { tag in
                        TagChip(tag: tag) {
                            withAnimation(ChatTheme.quick) {
                                model.toggle(tag)
                            }
                        }
                        .opacity(model.selectedTags.contains(tag.id) ? 1 : 0.48)
                    }
                }
            }
        }
    }

    private var platformPicker: some View {
        Picker("平台", selection: $model.platform) {
            ForEach(ChatPlatform.allCases) { platform in
                Text(platform.displayName).tag(platform)
            }
        }
        .pickerStyle(.segmented)
    }

    private func senderPicker(allowSystem: Bool) -> some View {
        Picker("发送者", selection: $model.sender) {
            ForEach(allowSystem ? MessageSender.allCases : [.peer, .me], id: \.self) { sender in
                Text(sender.displayName).tag(sender)
            }
        }
        .pickerStyle(.segmented)
    }

    private func supportedFormatRow(_ app: String, _ format: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(app)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(ChatTheme.primaryText)
                .frame(width: 46, alignment: .leading)
            Text(format)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ChatTheme.secondaryText)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(ChatTheme.surface(for: colorScheme))
            .stroke(Color.black.opacity(0.05), lineWidth: 1)
    }

    private func captionField(
        _ title: String,
        text: Binding<String>,
        prompt: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ChatTheme.secondaryText)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .padding(10)
                .background(fieldBackground)
        }
    }

    private struct LabeledEditor: View {
        let title: String
        @Binding var text: String
        let minHeight: CGFloat
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ChatTheme.secondaryText)
                TextEditor(text: $text)
                    .font(.system(size: 14))
                    .frame(minHeight: minHeight)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ChatTheme.surface(for: colorScheme))
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
            }
        }
    }
}
final class MessageCaptureModel: ObservableObject {
    @Published var mode = MessageCaptureModel.CaptureMode.single
    @Published var text = ""
    @Published var platform: ChatPlatform = .wechat
    @Published var sender: MessageSender = .peer
    @Published var sentAt = Date()
    @Published var externalTitle = ""
    @Published var externalURL = ""
    @Published var selectedTags: Set<UUID> = []
    @Published var selectedFileName: String?
    @Published var selectedFileURL: URL?
    @Published var selectedFileData: Data?
    @Published var detectedFormat: ImportFormat?
    @Published var importOutput: ImportOutput?
    @Published var errorMessage: String?
    @Published var isProcessing = false
    @Published var importSummary: String?
    @Published var discoveredArchives: [DiscoveredChatArchive] = []
    @Published var scanResult: ChatArchiveScanResult?
    @Published var selectedArchiveID: String?
    @Published var isScanningArchives = false
    @Published var scanErrorMessage: String?
    var scanFolderAccessURL: URL?
    var didStartScanFolderAccess = false

    enum CaptureMode: String, CaseIterable, Identifiable {
        case single
        case realFile

        var id: String { rawValue }
        var title: String {
            switch self {
            case .single: "单条"
            case .realFile: "真实记录文件"
            }
        }
    }

    var canSave: Bool {
        switch mode {
        case .single:
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .realFile:
            return selectedFileURL != nil && selectedFileData != nil && importOutput != nil && !isProcessing
        }
    }

    func toggle(_ tag: ChatTag) {
        if selectedTags.contains(tag.id) {
            selectedTags.remove(tag.id)
        } else {
            selectedTags.insert(tag.id)
        }
    }

    @MainActor
    func selectFile(from result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                isProcessing = true
                errorMessage = nil
                selectedFileURL = url
                selectedFileName = url.lastPathComponent
                selectedFileData = data

                let importer = RealChatImporter()
                let output = try importer.parse(data: data, url: url)
                detectedFormat = output.format
                importOutput = output
            } catch {
                selectedFileName = nil
                selectedFileURL = nil
                selectedFileData = nil
                detectedFormat = nil
                importOutput = nil
                errorMessage = "读取失败：\(error.localizedDescription)"
            }

            isProcessing = false

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func scanWeChatLocations() {
        guard !isScanningArchives else { return }
        isScanningArchives = true
        scanErrorMessage = nil

        Task.detached(priority: .userInitiated) { [weak self] in
            let result = ChatArchiveScanner().scanWeChatLocations()
            await MainActor.run {
                self?.scanResult = result
                self?.discoveredArchives = result.archives
                self?.isScanningArchives = false
            }
        }
    }

    @MainActor
    func selectScanFolder(from result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            releaseScanFolderAccess()
            let didStartAccess = url.startAccessingSecurityScopedResource()
            scanFolderAccessURL = url
            didStartScanFolderAccess = didStartAccess
            scanDirectories(at: url)

        case .failure(let error):
            scanErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    func scanDirectories(at url: URL) {
        guard !isScanningArchives else { return }
        isScanningArchives = true
        scanErrorMessage = nil

        Task.detached(priority: .userInitiated) { [weak self] in
            let result = ChatArchiveScanner().scanDirectories(
                at: [url],
                platform: .wechat,
                format: .wechatSQLite
            )
            await MainActor.run {
                self?.scanResult = result
                self?.discoveredArchives = result.archives
                self?.isScanningArchives = false
            }
        }
    }

    @MainActor
    func select(_ archive: DiscoveredChatArchive) {
        selectedArchiveID = archive.id
        loadArchive(at: archive.url)
    }

    @MainActor
    private func loadArchive(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            errorMessage = nil
            selectedFileURL = url
            selectedFileName = url.lastPathComponent
            selectedFileData = data

            let importer = RealChatImporter()
            let output = try importer.parse(data: data, url: url)
            detectedFormat = output.format
            importOutput = output
        } catch {
            selectedFileURL = nil
            selectedFileName = nil
            selectedFileData = nil
            detectedFormat = nil
            importOutput = nil
            errorMessage = "读取失败：\(error.localizedDescription)"
        }
    }

    func releaseScanFolderAccess() {
        if didStartScanFolderAccess, let scanFolderAccessURL {
            scanFolderAccessURL.stopAccessingSecurityScopedResource()
        }
        scanFolderAccessURL = nil
        didStartScanFolderAccess = false
    }

    func save(to store: ChatStore) {
        guard let personID = store.selectedPersonID else { return }

        switch mode {
        case .single:
            store.addMessage(
                personID: personID,
                platform: platform,
                sender: sender,
                sentAt: sentAt,
                text: text,
                externalTitle: externalTitle,
                externalURL: externalURL,
                tagIDs: selectedTags
            )

        case .realFile:
            guard let output = importOutput,
                  let url = selectedFileURL else { return }
            store.importRealRecords(
                output.records,
                personID: personID,
                fileName: url.lastPathComponent,
                format: output.format
            )
        }
    }

    @MainActor
    func importDecryptedWechatDirectory(
        from result: Result<[URL], Error>,
        store: ChatStore
    ) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                isProcessing = true
                errorMessage = nil

                let fileManager = FileManager.default
                let exportFiles = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey]
                )?.compactMap { $0 as? URL }
                    .filter { $0.lastPathComponent == "messages.json" } ?? []

                if !exportFiles.isEmpty {
                    Task.detached(priority: .userInitiated) { [weak self] in
                        do {
                            let importer = RealChatImporter()
                            var records: [RawImportRecord] = []
                            var warnings: [String] = []

                            for fileURL in exportFiles.sorted(by: { $0.path < $1.path }) {
                                let data = try Data(contentsOf: fileURL)
                                let output = try importer.parse(data: data, url: fileURL)
                                records.append(contentsOf: output.records)
                                warnings.append(contentsOf: output.warnings)
                            }

                            guard !records.isEmpty else {
                                let reason = warnings.joined(separator: "\n")
                                throw ImportError(message: reason.isEmpty ? "导出目录中没有可导入消息。" : reason)
                            }

                            let importedRecords = records
                            await MainActor.run { [weak self] in
                                guard let self else { return }
                                let batch = store.importRealRecords(
                                    importedRecords,
                                    fileName: url.lastPathComponent,
                                    format: .wechatDataAnalysisExport
                                )
                                self.importSummary = "✅ WeChatDataAnalysis 导入完成：\(importedRecords.count) 条消息 / 跳过 \(batch?.skippedCount ?? 0) 条重复"
                                self.isProcessing = false
                            }
                        } catch {
                            await MainActor.run { [weak self] in
                                self?.errorMessage = "导入失败：\(error.localizedDescription)"
                                self?.isProcessing = false
                            }
                        }
                    }
                    return
                }

                let importer = WechatDecryptedImporter()
                let directoryImport = try importer.importDirectory(at: url)

                guard !directoryImport.conversations.isEmpty else {
                    throw ImportError(
                        message: directoryImport.warnings.joined(separator: "\n").isEmpty
                            ? "目录中没有解析到微信会话。"
                            : directoryImport.warnings.joined(separator: "\n")
                    )
                }

                let messageCount = directoryImport.conversations.reduce(0) { $0 + $1.messages.count }
                let batch = store.importWechatDecryptedDirectory(
                    directoryImport,
                    fileName: url.lastPathComponent
                )
                importSummary = "✅ 解密目录导入完成：\(directoryImport.conversations.count) 个联系人 / \(messageCount) 条消息 / 跳过 \(batch.skippedCount) 条重复"
            } catch {
                errorMessage = "导入失败：\(error.localizedDescription)"
            }

            isProcessing = false

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
