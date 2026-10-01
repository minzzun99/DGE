import SwiftUI
import SwiftData

@main
struct DGEApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState: AppState
    @AppStorage(SettingsKey.showMenuBarItem) private var showMenuBarItem = true
    private let container: ModelContainer

    init() {
        // 설정 기본값을 먼저 넣어야 AppState가 '시작 화면'을 제대로 읽는다.
        SettingsDefaults.register()

        do {
            container = try ModelContainer(for: TodoTask.self, TaskList.self, CalendarEvent.self, Note.self)
        } catch {
            fatalError("DGE 저장소를 열 수 없습니다: \(error)")
        }

        let state = AppState()
        _appState = State(initialValue: state)
        AppServices.shared = AppServices(container: container, appState: state)
    }

    var body: some Scene {
        Window("DGE", id: DGEWindow.main) {
            RootView()
                .environment(appState)
                .frame(minWidth: 1180, minHeight: 800)
                .dgeAppearance()
        }
        .modelContainer(container)
        .defaultSize(width: 1400, height: 900)
        .commands {
            DGECommands(appState: appState)
        }

        Window("오늘", id: DGEWindow.mini) {
            MiniWindowView()
                .dgeAppearance()
        }
        .modelContainer(container)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 264, height: 380)
        .defaultPosition(.topTrailing)

        Settings {
            SettingsView()
                .modelContainer(container)
        }

        MenuBarExtra(isInserted: menuBarItemBinding) {
            MenuBarView()
                .dgeAppearance()
                .modelContainer(container)
        } label: {
            MenuBarLabel()
                .modelContainer(container)
        }
        .menuBarExtraStyle(.window)
    }

    /// 시스템은 메뉴 막대 아이콘을 그릴 때마다 같은 값을 다시 써 넣는다.
    /// 그대로 `@AppStorage`에 쓰면 설정이 바뀐 것으로 알려져 장면을 다시 그리고, 또 써 넣기를 끝없이 되풀이한다.
    /// 값이 실제로 바뀔 때만 저장한다.
    private var menuBarItemBinding: Binding<Bool> {
        Binding(
            get: { showMenuBarItem },
            set: { if $0 != showMenuBarItem { showMenuBarItem = $0 } }
        )
    }
}
