import AppKit
import Darwin
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

var arguments = Array(CommandLine.arguments.dropFirst())
let checkOnly = arguments.first == "--check"
if checkOnly {
    arguments.removeFirst()
}
guard arguments.count >= 2 else {
    fail("Usage: file-associations.swift [--check] <bundle-id> <extension>...")
}
guard geteuid() != 0 else {
    fail("Run file association setup as the login user, without sudo.")
}

// Zed and IINA setup can run concurrently, but both edit the same preference.
if !checkOnly {
    let lockURL = FileManager.default.temporaryDirectory.appendingPathComponent("dotfiles-file-associations.lock")
    let descriptor = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard descriptor >= 0 else { fail("Cannot open the file association lock.") }
    let deadline = Date().addingTimeInterval(30)
    while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
        guard errno == EWOULDBLOCK, Date() < deadline else {
            fail("Another file association setup is running; retry after it finishes.")
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
}

let bundleID = arguments[0]
let extensions = Array(Set(arguments.dropFirst().map { $0.lowercased() })).sorted()
let workspace = NSWorkspace.shared
guard workspace.urlForApplication(withBundleIdentifier: bundleID) != nil else {
    fail("Install \(bundleID) before configuring its file associations.")
}
let types = extensions.map { fileExtension -> UTType in
    guard let type = UTType(filenameExtension: fileExtension) else {
        fail("Cannot resolve the content type for .\(fileExtension).")
    }
    return type
}

func isDefault(_ contentType: UTType) -> Bool {
    guard let current = workspace.urlForApplication(toOpen: contentType) else {
        return false
    }
    return Bundle(url: current)?.bundleIdentifier?.lowercased() == bundleID.lowercased()
}

let pending = Array(zip(extensions, types)).filter { !isDefault($0.1) }
if pending.isEmpty {
    print("File associations verified for \(bundleID).")
    exit(0)
}
if checkOnly {
    fail("File associations are still pending for \(bundleID): \(pending.map { "." + $0.0 }.joined(separator: ", ")). Sign out and back in, then rerun setup.")
}

let domain = "com.apple.LaunchServices/com.apple.launchservices.secure" as CFString
let key = "LSHandlers" as CFString
guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
    fail("Cannot read the current LaunchServices preferences.")
}
let stored = CFPreferencesCopyValue(key, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
guard stored == nil || stored is [[String: Any]] else {
    fail("Unexpected LaunchServices handlers; leaving them unchanged.")
}
var handlers = stored as? [[String: Any]] ?? []
let pendingTypes = Set(pending.map { $0.1.identifier })
handlers.removeAll { handler in
    if let identifier = handler["LSHandlerContentType"] as? String {
        return pendingTypes.contains(identifier)
    }
    if handler["LSHandlerContentTagClass"] as? String == "public.filename-extension",
       let tag = handler["LSHandlerContentTag"] as? String,
       let type = UTType(filenameExtension: tag.lowercased()) {
        return pendingTypes.contains(type.identifier)
    }
    return false
}
for (fileExtension, type) in pending {
    var handler: [String: Any] = [
        "LSHandlerRoleAll": bundleID,
        "LSHandlerPreferredVersions": ["LSHandlerRoleAll": "-"],
    ]
    if type.isDynamic {
        handler["LSHandlerContentTag"] = fileExtension
        handler["LSHandlerContentTagClass"] = "public.filename-extension"
    } else {
        handler["LSHandlerContentType"] = type.identifier
    }
    if !handlers.contains(where: { NSDictionary(dictionary: $0).isEqual(to: handler) }) {
        handlers.append(handler)
    }
}
CFPreferencesSetValue(key, handlers as CFArray, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
    fail("Cannot save the requested file associations.")
}

func run(_ executable: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    do { try process.run() } catch { fail(error.localizedDescription) }
    process.waitUntilExit()
    return process.terminationStatus
}

// NSWorkspace's setter prompts on recent macOS. Reload only this user's daemon
// after merging preferences, then verify through the public API in a fresh process.
let reloaded = run("/usr/bin/killall", ["-u", NSUserName(), "lsd"])
guard reloaded == 0 || reloaded == 1 else {
    fail("Associations saved, but LaunchServices could not reload. Sign out and back in, then rerun setup.")
}
exit(run("/usr/bin/xcrun", ["swift", #filePath, "--check", bundleID] + extensions))
