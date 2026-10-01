import AppKit
import Carbon.HIToolbox

/// 다른 앱을 쓰는 중에도 먹히는 단축키 하나. (빠른 입력 창)
///
/// Carbon의 `RegisterEventHotKey`를 쓴다. 손쉬운 사용 권한 없이도 동작하고,
/// 등록한 조합만 받기 때문에 키 입력을 엿보지 않는다.
@MainActor
final class GlobalHotKey {
    static let shared = GlobalHotKey()

    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    func register(_ shortcut: QuickEntryShortcut) {
        unregister()
        guard let keyCode = shortcut.keyCode else { return }
        installHandlerIfNeeded()

        // 'DGE!' — 우리 앱 단축키라는 표시.
        let id = EventHotKeyID(signature: OSType(0x4447_4521), id: 1)
        let status = RegisterEventHotKey(keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            print("[DGE] 전역 단축키 등록 실패: \(status)")
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            Task { @MainActor in GlobalHotKey.shared.onPress?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }
}
