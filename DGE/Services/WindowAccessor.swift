import SwiftUI
import AppKit

/// SwiftUI 뷰가 올라간 NSWindow를 꺼내온다.
/// "항상 위에 띄우기"처럼 SwiftUI에 아직 없는 창 설정을 만질 때만 쓴다.
struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        apply(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        apply(from: nsView)
    }

    /// 뷰가 창에 붙는 건 다음 차례라, 한 박자 뒤에 읽는다.
    private func apply(from view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configure(window)
        }
    }
}
