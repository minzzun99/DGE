import SwiftUI
import SwiftData
import AppKit

/// 어디서든 단축키로 불러내는 한 줄 입력 창. (Spotlight처럼 화면 위쪽에 뜬다)
///
/// 앱을 앞으로 가져오지 않는 패널이라, 쓰던 앱 위에서 바로 적고 Enter만 누르면 된다.
@MainActor
final class QuickEntryController: NSObject, NSWindowDelegate {
    private let container: ModelContainer
    private var panel: QuickEntryPanel?
    private let state = QuickEntryState()

    init(container: ModelContainer) {
        self.container = container
        super.init()
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        // 마우스가 있는 화면의 위쪽 가운데.
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - frame.height * 0.22 - size.height))
        }
        state.appearCount += 1
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> QuickEntryPanel {
        let panel = QuickEntryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 150),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        let root = QuickEntryView(state: state, onClose: { [weak self] in self?.close() })
            .dgeAppearance()
            .modelContainer(container)
        panel.contentView = NSHostingView(rootView: root)
        return panel
    }

    /// 다른 곳을 누르면 닫는다.
    nonisolated func windowDidResignKey(_ notification: Notification) {
        Task { @MainActor in self.close() }
    }
}

/// 테두리 없는 패널도 키 입력을 받게 한다.
final class QuickEntryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@Observable
@MainActor
final class QuickEntryState {
    /// 창이 뜰 때마다 늘어난다. 입력창이 이걸 보고 포커스를 가져간다.
    var appearCount = 0
}

private struct QuickEntryView: View {
    let state: QuickEntryState
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \TaskList.order) private var lists: [TaskList]
    @AppStorage(SettingsKey.smartInput) private var smartInput = true
    @State private var text = ""
    @State private var lastAdded: String?
    @FocusState private var isFocused: Bool

    private var parsed: ParsedTask {
        guard smartInput else { return ParsedTask(title: text.trimmingCharacters(in: .whitespaces)) }
        return QuickAddParser.parse(text, listNames: lists.map(\.name))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 24, height: 24)

                TextField("할 일 — 예: 내일 오후 3시 보고서 #업무 !!", text: $text)
                    .textFieldStyle(.plain)
                    .font(.dge(size: 18))
                    .focused($isFocused)
                    .onSubmit(submit)
                    .onExitCommand(perform: onClose)
            }

            HStack(spacing: 8) {
                if !text.isEmpty, parsed.hasHints {
                    ParseHints(parsed: parsed)
                } else if let lastAdded {
                    Label(lastAdded, systemImage: "checkmark.circle.fill")
                        .font(.dge(size: 12))
                        .foregroundStyle(DGE.Palette.secondaryText)
                } else {
                    Text("날짜 · 시각 · #태그 · !우선순위 · @목록 · 매주 같은 말을 알아듣습니다")
                        .font(.dge(size: 12))
                        .foregroundStyle(DGE.Palette.tertiaryText)
                }
                Spacer(minLength: 0)
                KeyHint("↵ 추가")
                KeyHint("esc 닫기")
            }
            .frame(height: 20)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 620)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DGE.Palette.canvas)
                .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(DGE.Palette.border, lineWidth: 1)
        )
        .padding(20)
        .onAppear { isFocused = true }
        .onChange(of: state.appearCount) { _, _ in
            lastAdded = nil
            isFocused = true
        }
    }

    private func submit() {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            onClose()
            return
        }
        guard let task = TaskStore(context: context).create(parsed) else { return }
        let destination = task.dueDate.map { $0.dgeDayTitle } ?? "수신함"
        lastAdded = "‘\(task.displayTitle)’ → \(destination)"
        text = ""
        // 들어간 곳을 잠깐 보여주고 닫는다. 그 사이 또 적기 시작하면 열어 둔다.
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            if text.isEmpty { onClose() }
        }
    }
}
