import SwiftUI
import SwiftData
import UserNotifications
import UniformTypeIdentifiers

/// 설정 창(⌘,). 좋은 기본값을 두고, 바꿀 만한 것만 모았다.
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("일반", systemImage: "gearshape") { GeneralSettings() }
            Tab("모양", systemImage: "paintpalette") { AppearanceSettings() }
            Tab("알림", systemImage: "bell") { NotificationSettings() }
            Tab("캘린더", systemImage: "calendar") { CalendarSettings() }
            Tab("단축키", systemImage: "keyboard") { ShortcutSettings() }
            Tab("데이터", systemImage: "externaldrive") { DataSettings() }
        }
        .frame(width: 540)
        .frame(minHeight: 420)
        .dgeAppearance()
    }
}

// MARK: - 일반

private struct GeneralSettings: View {
    @AppStorage(SettingsKey.startScreen) private var startScreen = StartScreen.today.rawValue
    @AppStorage(SettingsKey.dockBadge) private var dockBadge = true
    @AppStorage(SettingsKey.showMenuBarItem) private var showMenuBarItem = true
    @AppStorage(SettingsKey.menuBarCount) private var menuBarCount = true
    @AppStorage(SettingsKey.smartInput) private var smartInput = true

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Picker("앱을 열면", selection: $startScreen) {
                    ForEach(StartScreen.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Toggle("로그인할 때 자동으로 열기", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LoginItem.set(enabled)
                            loginError = nil
                        } catch {
                            loginError = "바꾸지 못했습니다: \(error.localizedDescription)"
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }

            Section("표시") {
                Toggle("Dock 아이콘에 오늘 남은 개수 표시", isOn: $dockBadge)
                Toggle("메뉴 막대에 아이콘 두기", isOn: $showMenuBarItem)
                Toggle("메뉴 막대 아이콘 옆에 개수 표시", isOn: $menuBarCount)
                    .disabled(!showMenuBarItem)
            }

            Section {
                Toggle("입력창에서 날짜 · 태그 · 우선순위 알아듣기", isOn: $smartInput)
            } header: {
                Text("입력")
            } footer: {
                Text("“내일 오후 3시 보고서 #업무 !! @공부 매주”처럼 적으면 날짜, 알림, 태그, 우선순위(! · !! · !!!), 목록, 반복으로 나눠 넣습니다.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }
}

// MARK: - 모양

private struct AppearanceSettings: View {
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceSetting.system.rawValue
    @Bindable private var store = AppearanceStore.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        Form {
            Section("화면 모드") {
                Picker("화면 모드", selection: $appearance) {
                    ForEach(AppearanceSetting.allCases) { Text($0.shortTitle).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ThemeSetting.allCases) { theme in
                        ThemeCard(theme: theme, isSelected: store.theme == theme) {
                            store.theme = theme
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("테마")
            } footer: {
                Text("체크 · 포커스 · 오늘 표시에 쓰는 강조색과 바탕의 옅은 색이 바뀝니다. 라이트와 다크 모드에 각각 맞춰 두었습니다.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("텍스트 크기", selection: $store.textSize) {
                    ForEach(TextSizeSetting.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                TextSizePreview()
            } header: {
                Text("텍스트 크기")
            } footer: {
                Text("할 일 목록, 상세 정보, 캘린더, 사이드바, 메뉴 막대 · 미니 창의 글자를 함께 바꿉니다.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// 테마를 고르는 작은 창 그림. 실제 바탕 · 한 겹 올라온 면 · 강조색을 그대로 쓴다.
private struct ThemeCard: View {
    let theme: ThemeSetting
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                preview
                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.accent)
                    }
                    Text(theme.title)
                        .fontWeight(isSelected ? .semibold : .regular)
                }
                .font(.system(size: 12))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.title) 테마")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var preview: some View {
        HStack(spacing: 0) {
            // 사이드바 자리
            ZStack {
                theme.surface
                theme.sidebarTint
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 7) {
                row(checked: true, width: 34)
                row(checked: false, width: 52)
                row(checked: false, width: 40)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(theme.canvas)
        }
        .frame(height: 64)
        .clipShape(RoundedRectangle(cornerRadius: DGE.Radius.control + 1, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DGE.Radius.control + 1, style: .continuous)
                .strokeBorder(isSelected ? theme.accent : DGE.Palette.border, lineWidth: isSelected ? 2 : 1)
        )
    }

    private func row(checked: Bool, width: CGFloat) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(checked ? theme.accent : Color.clear)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 1).opacity(checked ? 0 : 1))
                .frame(width: 9, height: 9)
            Capsule()
                .fill(Color.primary.opacity(checked ? 0.14 : 0.3))
                .frame(width: width, height: 4)
        }
    }
}

/// 고른 텍스트 크기로 할 일 한 줄이 어떻게 보이는지.
private struct TextSizePreview: View {
    var body: some View {
        HStack(spacing: 10) {
            Checkbox(isChecked: false) {}
            VStack(alignment: .leading, spacing: 3) {
                Text("분기 보고서 초안 보내기")
                    .font(DGE.Typography.taskTitle)
                    .foregroundStyle(DGE.Palette.primaryText)
                Text("오늘 · 오후 3시 · #업무")
                    .font(DGE.Typography.meta)
                    .foregroundStyle(DGE.Palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DGE.Radius.row, style: .continuous)
                .fill(DGE.Palette.canvas)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DGE.Radius.row, style: .continuous)
                .strokeBorder(DGE.Palette.hairline, lineWidth: 1)
        )
        .animation(DGE.Motion.list, value: AppearanceStore.shared.textSize)
        .accessibilityHidden(true)
    }
}

// MARK: - 알림

private struct NotificationSettings: View {
    @AppStorage(SettingsKey.dailySummary) private var dailySummary = false
    @AppStorage(SettingsKey.dailySummaryMinutes) private var dailySummaryMinutes = 540
    @AppStorage(SettingsKey.defaultReminderMinutes) private var defaultReminderMinutes = 540

    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section {
                LabeledContent("알림 권한") {
                    HStack(spacing: 8) {
                        Text(statusText).foregroundStyle(.secondary)
                        switch status {
                        case .notDetermined:
                            Button("허용하기") {
                                Task {
                                    await AppServices.shared?.notifications.requestAuthorization()
                                    await refresh()
                                }
                            }
                        case .denied:
                            Button("시스템 설정 열기") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                            }
                        default:
                            Button("시험 알림") { AppServices.shared?.notifications.sendTest() }
                        }
                    }
                }
            } footer: {
                Text("할 일의 알림 시각과 일정의 알림을 이 Mac의 알림 센터로 보냅니다. 알림에서 바로 ‘완료’나 ‘10분 뒤 다시’를 누를 수 있습니다.")
                    .foregroundStyle(.secondary)
            }

            Section("할 일") {
                DatePicker("‘알림 추가’를 누르면", selection: minutesBinding($defaultReminderMinutes), displayedComponents: .hourAndMinute)
            }

            Section {
                Toggle("아침에 오늘 할 일 알려주기", isOn: $dailySummary)
                DatePicker("시각", selection: minutesBinding($dailySummaryMinutes), displayedComponents: .hourAndMinute)
                    .disabled(!dailySummary)
            } header: {
                Text("하루 요약")
            } footer: {
                Text("정한 시각에 그날 할 일 수와 첫 몇 개를 알려줍니다.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await refresh() }
    }

    private var statusText: String {
        switch status {
        case .authorized, .provisional, .ephemeral: "허용됨"
        case .denied: "꺼져 있음"
        default: "아직 묻지 않음"
        }
    }

    private func refresh() async {
        status = await AppServices.shared?.notifications.authorizationStatus() ?? .notDetermined
    }
}

// MARK: - 캘린더

private struct CalendarSettings: View {
    @AppStorage(SettingsKey.weekStart) private var weekStart = WeekStart.system.rawValue
    @AppStorage(SettingsKey.defaultEventMinutes) private var defaultEventMinutes = 60
    @AppStorage(SettingsKey.calendarShowsTasks) private var showsTasks = true
    @AppStorage(SettingsKey.showSystemCalendars) private var showSystemCalendars = false

    private var systemCalendar: SystemCalendar { SystemCalendar.shared }

    var body: some View {
        Form {
            Section {
                Picker("한 주의 시작", selection: $weekStart) {
                    ForEach(WeekStart.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("새 일정 기본 길이", selection: $defaultEventMinutes) {
                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                        Text(minutes < 60 ? "\(minutes)분" : minutes % 60 == 0 ? "\(minutes / 60)시간" : "1시간 30분")
                            .tag(minutes)
                    }
                }
                Toggle("캘린더에 할 일 함께 보기", isOn: $showsTasks)
            }

            Section {
                Toggle("macOS 캘린더 일정 보기", isOn: $showSystemCalendars)
                    .onChange(of: showSystemCalendars) { _, enabled in
                        guard enabled, !systemCalendar.isAuthorized else { return }
                        Task {
                            let granted = await systemCalendar.requestAccess()
                            if !granted { showSystemCalendars = false }
                        }
                    }
                if systemCalendar.status == .denied {
                    LabeledContent("권한이 꺼져 있습니다") {
                        Button("시스템 설정 열기") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                        }
                    }
                }
            } header: {
                Text("다른 캘린더")
            } footer: {
                Text("iCloud · Google 등 이 Mac의 캘린더 앱에 연결된 일정을 DGE 캘린더에 함께 보여줍니다. 읽기만 하고 바꾸지 않습니다.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 단축키

private struct ShortcutSettings: View {
    @AppStorage(SettingsKey.quickEntryShortcut) private var quickEntry = QuickEntryShortcut.controlOptionSpace.rawValue

    private let appShortcuts: [(String, String)] = [
        ("새 할 일", "⌘N"),
        ("검색 · 명령", "⌘K"),
        ("빠른 입력 창", "⇧⌘N"),
        ("수신함 · 오늘 · 예정 · 캘린더 · 완료 · 메모", "⌘1 – ⌘6"),
        ("완료 / 완료 취소", "⌘↩"),
        ("오늘로", "⌘T"),
        ("내일로 미루기", "⇧⌘T"),
        ("다음 주로 미루기", "⌥⌘T"),
        ("우선순위 높음 · 보통 · 낮음 · 없음", "⌃3 · ⌃2 · ⌃1 · ⌃0"),
        ("상세 정보", "⌘I"),
        ("삭제", "⌘⌫"),
        ("미니 창", "⇧⌘M"),
    ]

    var body: some View {
        Form {
            Section {
                Picker("빠른 입력 창 열기", selection: $quickEntry) {
                    ForEach(QuickEntryShortcut.allCases) { Text($0.title).tag($0.rawValue) }
                }
            } header: {
                Text("어디서나")
            } footer: {
                Text("다른 앱을 쓰는 중에도 이 단축키로 한 줄 입력 창을 불러 할 일을 바로 적을 수 있습니다. 입력 소스 전환(⌃Space)과 겹치지 않는 조합을 고르세요.")
                    .foregroundStyle(.secondary)
            }

            Section("앱 안에서") {
                ForEach(appShortcuts, id: \.0) { title, keys in
                    LabeledContent(title) {
                        Text(keys)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 데이터

private struct DataSettings: View {
    @Environment(\.modelContext) private var context
    @Query private var tasks: [TodoTask]
    @Query private var events: [CalendarEvent]
    @Query private var lists: [TaskList]
    @Query private var notes: [Note]

    @State private var message: String?
    @State private var cleanupDays: Int?

    private var completedCount: Int {
        tasks.filter(\.isCompleted).count
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("할 일") { Text("\(tasks.count)개 (완료 \(completedCount)개)").foregroundStyle(.secondary) }
                LabeledContent("일정") { Text("\(events.count)개").foregroundStyle(.secondary) }
                LabeledContent("메모") { Text("\(notes.count)개").foregroundStyle(.secondary) }
                LabeledContent("목록") { Text("\(lists.count)개").foregroundStyle(.secondary) }
            }

            Section {
                LabeledContent("백업 파일로 내보내기") {
                    Button("내보내기…", action: exportBackup)
                }
                LabeledContent("백업 파일 가져오기") {
                    Button("가져오기…", action: importBackup)
                }
            } header: {
                Text("백업")
            } footer: {
                Text("가져오기는 지금 있는 것은 그대로 두고, 없는 것만 더합니다.")
                    .foregroundStyle(.secondary)
            }

            Section("정리") {
                LabeledContent("오래된 완료 항목 지우기") {
                    HStack {
                        Button("30일 지난 것") { cleanupDays = 30 }
                        Button("90일 지난 것") { cleanupDays = 90 }
                    }
                }
            }

            if let message {
                Section {
                    Text(message).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "끝낸 지 \(cleanupDays ?? 0)일이 지난 할 일을 지울까요?",
            isPresented: Binding(get: { cleanupDays != nil }, set: { if !$0 { cleanupDays = nil } })
        ) {
            Button("지우기", role: .destructive) {
                if let days = cleanupDays {
                    let count = TaskStore(context: context).deleteCompleted(olderThan: days)
                    message = "완료 항목 \(count)개를 지웠습니다."
                }
                cleanupDays = nil
            }
        } message: {
            Text("지운 뒤에는 되돌릴 수 없습니다. 먼저 백업해 두는 것을 권합니다.")
        }
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "DGE 백업 \(Date().formatted(.iso8601.year().month().day())).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try BackupService(context: context).export().write(to: url, options: .atomic)
            message = "\(url.lastPathComponent)에 저장했습니다."
        } catch {
            message = "내보내지 못했습니다: \(error.localizedDescription)"
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let result = try BackupService(context: context).merge(Data(contentsOf: url))
            message = "할 일 \(result.tasks)개, 일정 \(result.events)개, 메모 \(result.notes)개, 목록 \(result.lists)개를 더했습니다."
        } catch {
            message = "가져오지 못했습니다. DGE 백업 파일인지 확인해 주세요."
        }
    }
}

/// "자정부터 몇 분"으로 저장한 값을 시각 선택기에 연결한다.
private func minutesBinding(_ minutes: Binding<Int>) -> Binding<Date> {
    Binding(
        get: { Date.startOfToday.at(minutes: minutes.wrappedValue) },
        set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes.wrappedValue = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    )
}
