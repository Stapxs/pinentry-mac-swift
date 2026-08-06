import AppKit

protocol IconResolving {
    func resolve(_ source: DialogModel.IconSource) -> NSImage?
}

struct IconResolver: IconResolving {
    func resolve(_ source: DialogModel.IconSource) -> NSImage? {
        switch source {
        case .systemSymbol:
            return nil
        case .bundledImage(let name):
            return NSImage(named: name)
        case .filePath(let path):
            return NSImage(contentsOfFile: path)
        case .appIcon:
            if let image = NSImage(named: "Icon") {
                return image
            }

            return NSApplication.shared.applicationIconImage
        }
    }
}
