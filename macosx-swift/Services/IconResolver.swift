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
        case .ownerProcessID(let processID):
            return resolveCallerApplicationIcon(ownerPID: processID)
        case .appIcon:
            if let image = AppRuntimeBundle.bundle.image(forResource: NSImage.Name("Icon")) {
                return image
            }

            return NSApplication.shared.applicationIconImage
        }
    }

    private func resolveCallerApplicationIcon(ownerPID: Int) -> NSImage? {
        var currentPID = ownerPID
        var visited = Set<Int>()

        while currentPID > 1, visited.insert(currentPID).inserted, visited.count <= 12 {
            if let icon = resolveRunningApplicationIcon(processID: currentPID) {
                return icon
            }

            let parentPID = Int(PinentryMacSwiftCopyParentProcessID(Int32(currentPID)))
            guard parentPID > 1, parentPID != currentPID else {
                break
            }

            currentPID = parentPID
        }

        return nil
    }

    private func resolveRunningApplicationIcon(processID: Int) -> NSImage? {
        let pid = pid_t(processID)
        guard let application = NSRunningApplication(processIdentifier: pid) else {
            return nil
        }

        if
            let bundleIdentifier = application.bundleIdentifier,
            bundleIdentifier == AppRuntimeBundle.bundle.bundleIdentifier
        {
            return nil
        }

        if
            let bundleURL = preferredApplicationBundleURL(for: application.bundleURL)
        {
            let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
            if icon.isValid {
                return icon
            }
        }

        return application.icon
    }

    private func preferredApplicationBundleURL(for bundleURL: URL?) -> URL? {
        guard let bundleURL else {
            return nil
        }

        let candidates = [
            bundleURL.standardizedFileURL,
            bundleURL.resolvingSymlinksInPath().standardizedFileURL
        ]

        for candidate in candidates {
            if let appBundleURL = outermostApplicationBundleURL(containing: candidate) {
                return appBundleURL
            }
        }

        return nil
    }

    private func outermostApplicationBundleURL(containing url: URL) -> URL? {
        var currentURL = url
        var resolvedBundleURL: URL?

        while currentURL.path != "/" {
            if currentURL.pathExtension == "app" {
                resolvedBundleURL = currentURL
            }

            currentURL.deleteLastPathComponent()
        }

        return resolvedBundleURL
    }
}
