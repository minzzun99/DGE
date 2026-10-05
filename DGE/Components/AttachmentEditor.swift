import SwiftUI
import QuickLook
import UniformTypeIdentifiers

/// 할 일에 붙인 사진. 고르기 · 붙여넣기 · 끌어놓기로 넣고, 누르면 훑어보기로 크게 본다.
struct AttachmentEditor: View {
    let task: TodoTask
    let onAdd: ([String]) -> Void
    let onRemove: (String) -> Void

    @State private var previewURL: URL?
    @State private var isTargeted = false

    private var urls: [URL] {
        task.attachments.map(AttachmentStore.url(for:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !task.attachments.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(task.attachments, id: \.self) { name in
                        AttachmentThumbnail(
                            name: name,
                            onOpen: { previewURL = AttachmentStore.url(for: name) },
                            onRemove: { withAnimation(DGE.Motion.list) { onRemove(name) } }
                        )
                    }
                }
            }

            HStack(spacing: 6) {
                ChipButton(title: "사진 추가", icon: "photo.badge.plus", action: pickFiles)
                ChipButton(title: "붙여넣기", icon: "doc.on.clipboard", help: "클립보드의 사진이나 스크린샷", action: paste)
                Text("끌어다 놓아도 됩니다")
                    .font(DGE.Typography.meta)
                    .foregroundStyle(DGE.Palette.tertiaryText)
            }
        }
        .padding(isTargeted ? 6 : 0)
        .background {
            if isTargeted {
                RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous)
                    .fill(DGE.Palette.accentSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous)
                            .strokeBorder(DGE.Palette.accent, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            }
        }
        .padding(isTargeted ? -6 : 0)
        .animation(DGE.Motion.hover, value: isTargeted)
        .dropDestination(for: URL.self) { dropped, _ in
            let names = dropped.filter(\.isFileURL).compactMap { try? AttachmentStore.importFile(at: $0) }
            add(names)
            return !names.isEmpty
        } isTargeted: { isTargeted = $0 }
        .quickLookPreview($previewURL, in: urls)
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.prompt = "추가"
        guard panel.runModal() == .OK else { return }
        add(panel.urls.compactMap { try? AttachmentStore.importFile(at: $0) })
    }

    private func paste() {
        let names = AttachmentStore.importPasteboard()
        if names.isEmpty { NSSound.beep() }
        add(names)
    }

    private func add(_ names: [String]) {
        guard !names.isEmpty else { return }
        withAnimation(DGE.Motion.list) { onAdd(names) }
    }
}

/// 사진 한 장. 정사각형으로 잘라 보여준다.
private struct AttachmentThumbnail: View {
    let name: String
    let onOpen: () -> Void
    let onRemove: () -> Void

    @State private var image: NSImage?
    @State private var isMissing = false
    @State private var isHovering = false

    private var url: URL { AttachmentStore.url(for: name) }

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else if isMissing {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.dge(size: 16))
                        .foregroundStyle(DGE.Palette.tertiaryText)
                        .help("사진 파일을 찾을 수 없습니다")
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .background(DGE.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DGE.Radius.field, style: .continuous)
                    .strokeBorder(DGE.Palette.border, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.dge(size: 14))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .help("사진 빼기")
                .padding(4)
                .opacity(isHovering ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .onHover { isHovering = $0 }
            .animation(DGE.Motion.hover, value: isHovering)
            .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
            .contextMenu {
                Button("훑어보기", action: onOpen)
                Button("기본 앱으로 열기") { NSWorkspace.shared.open(url) }
                Button("Finder에서 보기") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                Divider()
                Button("사진 빼기", role: .destructive, action: onRemove)
            }
            .task(id: name) {
                image = await AttachmentStore.thumbnail(for: name, maxPixel: 240)
                isMissing = image == nil
            }
    }
}
