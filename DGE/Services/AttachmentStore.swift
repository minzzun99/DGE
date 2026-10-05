import AppKit
import ImageIO
import UniformTypeIdentifiers

/// 할 일에 붙인 사진을 일반 파일로 보관한다.
///
/// Obsidian이 첨부 파일을 보관함 폴더에 그대로 두는 것처럼, 데이터베이스에는 파일 이름만 적고
/// 사진은 이 폴더에 원본 그대로 둔다. 그래서 백업은 이 폴더의 파일을 복사해 가면 된다.
///
/// 할 일을 지우거나 사진을 빼도 파일은 바로 지우지 않는다. "실행 취소"로 되살릴 수 있어야 해서,
/// 아무도 가리키지 않는 파일은 다음에 앱을 켤 때 `removeUnused`로 정리한다.
enum AttachmentStore {
    static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "DGE/Attachments", directoryHint: .isDirectory)
    }

    static func url(for name: String) -> URL {
        directory.appending(path: name, directoryHint: .notDirectory)
    }

    static func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: name).path)
    }

    // MARK: - 넣기

    /// 이미지 파일을 복사해 넣고 새 파일 이름을 돌려준다. 이미지가 아니면 nil.
    static func importFile(at source: URL) throws -> String? {
        let ext = source.pathExtension.lowercased()
        guard let type = UTType(filenameExtension: ext), type.conforms(to: .image) else { return nil }
        let name = newName(ext: ext)
        try createDirectory()
        try FileManager.default.copyItem(at: source, to: url(for: name))
        return name
    }

    /// 파일이 아닌 이미지(클립보드의 스크린샷 등)는 PNG로 저장한다.
    static func importImage(_ image: NSImage) throws -> String? {
        guard let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return nil }
        let name = newName(ext: "png")
        try createDirectory()
        try png.write(to: url(for: name), options: .atomic)
        return name
    }

    /// 클립보드에 이미지 파일이 있으면 그 파일을, 없으면 이미지 자체를 넣는다.
    static func importPasteboard(_ pasteboard: NSPasteboard = .general) -> [String] {
        let fromFiles = imageFileURLs(in: pasteboard).compactMap { try? importFile(at: $0) }
        if !fromFiles.isEmpty { return fromFiles }

        let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage] ?? []
        return images.compactMap { try? importImage($0) }
    }

    /// ⌘V를 사진 붙이기로 받을지.
    /// Finder에서 복사한 사진 파일은 언제나 사진으로 받는다. 스크린샷 같은 이미지는,
    /// 글을 쓰는 중이고 클립보드에 글자도 함께 있으면 글자 붙여넣기를 막지 않는다.
    static func pasteboardWantsAttachment(editingText: Bool, _ pasteboard: NSPasteboard = .general) -> Bool {
        if !imageFileURLs(in: pasteboard).isEmpty { return true }
        guard pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) else { return false }
        return !(editingText && pasteboard.canReadObject(forClasses: [NSString.self], options: nil))
    }

    private static func imageFileURLs(in pasteboard: NSPasteboard) -> [URL] {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return urls.filter { UTType(filenameExtension: $0.pathExtension.lowercased())?.conforms(to: .image) ?? false }
    }

    /// 백업 폴더에서 가져올 때. 같은 이름의 파일이 이미 있으면 그대로 둔다.
    static func copyIn(_ name: String, from folder: URL) throws {
        guard !exists(name) else { return }
        let source = folder.appending(path: name, directoryHint: .notDirectory)
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        try createDirectory()
        try FileManager.default.copyItem(at: source, to: url(for: name))
    }

    // MARK: - 정리

    /// 어떤 할 일도 가리키지 않는 파일을 지운다. 지운 개수를 돌려준다.
    @discardableResult
    static func removeUnused(keeping used: Set<String>) -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        var removed = 0
        for name in files where !used.contains(name) && !name.hasPrefix(".") {
            if (try? FileManager.default.removeItem(at: url(for: name))) != nil { removed += 1 }
        }
        return removed
    }

    // MARK: - 미리보기

    private static let thumbnails = NSCache<NSString, NSImage>()

    /// 긴 변이 `maxPixel`인 미리보기. 원본을 통째로 읽지 않아 큰 사진도 가볍다.
    static func thumbnail(for name: String, maxPixel: Int) async -> NSImage? {
        let key = "\(name)@\(maxPixel)" as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }

        let fileURL = url(for: name)
        let cgImage = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }.value

        guard let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: .zero)
        thumbnails.setObject(image, forKey: key)
        return image
    }

    // MARK: -

    private static func newName(ext: String) -> String {
        "\(UUID().uuidString).\(ext.isEmpty ? "png" : ext)"
    }

    private static func createDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
