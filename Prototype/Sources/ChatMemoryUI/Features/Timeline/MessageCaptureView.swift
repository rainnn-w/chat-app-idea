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
        .frame(width: 580, height: model.mode == .single ? 590 : 650)
        .background(ChatTheme.canvasGradient(for: colorScheme))
        .animation(ChatTheme.smooth, value: model.mode)
        .fileImporter(
            isPresented: $store.isSelectingRecordFile,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            model.selectFile(from: result)
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

                if model.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
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
        }
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
}
