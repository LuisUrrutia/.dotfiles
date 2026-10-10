import AppKit
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 2 else {
    fail("Usage: file-associations.swift <bundle-id> <extension>...")
}
let bundleID = arguments[0]
let extensions = Array(arguments.dropFirst())
let workspace = NSWorkspace.shared
guard let application = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
    fail("Install \(bundleID) before configuring its file associations.")
}

func isDefault(_ contentType: UTType) -> Bool {
    guard let current = workspace.urlForApplication(toOpen: contentType) else {
        return false
    }
    return Bundle(url: current)?.bundleIdentifier == bundleID
}

func apply(_ index: Int) {
    guard index < extensions.count else {
        print("File associations verified for \(bundleID).")
        exit(0)
    }
    let fileExtension = extensions[index]
    guard let contentType = UTType(filenameExtension: fileExtension) else {
        fail("Cannot resolve the content type for .\(fileExtension).")
    }
    if isDefault(contentType) {
        apply(index + 1)
        return
    }

    FileHandle.standardError.write(Data(
        "Setting .\(fileExtension) to \(bundleID); confirm any macOS dialog.\n".utf8
    ))
    let timeout = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { _ in
        fail(".\(fileExtension) is pending. Complete the macOS dialog and rerun setup.")
    }
    workspace.setDefaultApplication(at: application, toOpen: contentType) { error in
        DispatchQueue.main.async {
            timeout.invalidate()
            if let error = error {
                fail("Cannot set .\(fileExtension): \(error.localizedDescription)")
            }
            guard isDefault(contentType) else {
                fail("macOS did not change .\(fileExtension) to \(bundleID). Rerun setup after confirmation.")
            }
            apply(index + 1)
        }
    }
}

apply(0)
RunLoop.main.run()
