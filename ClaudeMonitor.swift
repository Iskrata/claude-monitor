import AppKit

struct ActiveInstance {
    let pid: Int
    let project: String
}

struct WaitingSession {
    let sessionId: String
    let project: String
}

func shell(_ cmd: String) -> String {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: "/bin/bash")
    p.arguments = ["-c", cmd]
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    try? p.run()
    p.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

func getActiveInstances() -> [ActiveInstance] {
    let raw = shell("ps -eo pid,%cpu,command | grep '[c]laude --'")
    return raw.split(separator: "\n").compactMap { line in
        let cols = line.split(separator: " ", maxSplits: 2)
        guard cols.count >= 3,
              let pid = Int(cols[0]),
              let cpu = Double(cols[1]),
              cpu > 3.0 else { return nil }
        let cwd = shell("lsof -p \(pid) -a -d cwd -Fn 2>/dev/null | grep ^n | head -1")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .dropFirst()
        let project = String(cwd).split(separator: "/").last.map(String.init) ?? "unknown"
        return ActiveInstance(pid: pid, project: project)
    }
}

func getWaitingSessions() -> [WaitingSession] {
    let dir = NSString(string: "~/.claude/monitor/waiting").expandingTildeInPath
    guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
    return files.compactMap { file in
        let path = "\(dir)/\(file)"
        guard let cwd = try? String(contentsOfFile: path, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !cwd.isEmpty else { return nil }
        let project = cwd.split(separator: "/").last.map(String.init) ?? "unknown"
        return WaitingSession(sessionId: file, project: project)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        let active = getActiveInstances()
        let waiting = getWaitingSessions()

        statusItem.button?.title = "\(active.count)\u{26A1}\(waiting.count)"

        let menu = NSMenu()

        if !active.isEmpty {
            menu.addItem(NSMenuItem(title: "— Active —", action: nil, keyEquivalent: ""))
            for inst in active {
                menu.addItem(NSMenuItem(title: "\(inst.project) (PID \(inst.pid))", action: nil, keyEquivalent: ""))
            }
        }
        if !waiting.isEmpty {
            menu.addItem(NSMenuItem(title: "— Waiting —", action: nil, keyEquivalent: ""))
            for s in waiting {
                menu.addItem(NSMenuItem(title: s.project, action: nil, keyEquivalent: ""))
            }
        }
        if active.isEmpty && waiting.isEmpty {
            menu.addItem(NSMenuItem(title: "No sessions", action: nil, keyEquivalent: ""))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
