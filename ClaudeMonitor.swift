import AppKit

struct RunningProcess {
    let pid: Int
    let cpu: Double
    let cwd: String
    let project: String
}

struct WaitingInfo {
    let sessionId: String
    let cwd: String
    let project: String
    let type: String
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

func getRunningProcesses() -> [RunningProcess] {
    let raw = shell("ps -eo pid,%cpu,command | grep '[c]laude --'")
    return raw.split(separator: "\n").compactMap { line in
        let cols = line.split(separator: " ", maxSplits: 2)
        guard cols.count >= 3,
              let pid = Int(cols[0]),
              let cpu = Double(cols[1]) else { return nil }
        let cwd = shell("lsof -p \(pid) -a -d cwd -Fn 2>/dev/null | grep ^n | head -1")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cwdPath = cwd.hasPrefix("n") ? String(cwd.dropFirst()) : cwd
        let project = cwdPath.split(separator: "/").last.map(String.init) ?? "unknown"
        return RunningProcess(pid: pid, cpu: cpu, cwd: cwdPath, project: project)
    }
}

func getWaitingInfos() -> [WaitingInfo] {
    let dir = NSString(string: "~/.claude/monitor/waiting").expandingTildeInPath
    guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
    let oneHourAgo = Date().addingTimeInterval(-3600)
    return files.compactMap { file in
        let path = "\(dir)/\(file)"
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        if let mod = attrs?[.modificationDate] as? Date, mod < oneHourAgo {
            try? FileManager.default.removeItem(atPath: path)
            return nil
        }
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let lines = content.split(separator: "\n", maxSplits: 1)
        let cwd = lines.first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let type = lines.count > 1 ? String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines) : "unknown"
        guard !cwd.isEmpty else { return nil }
        let project = cwd.split(separator: "/").last.map(String.init) ?? "unknown"
        return WaitingInfo(sessionId: file, cwd: cwd, project: project, type: type)
    }
}

func activateTerminal(forPID pid: Int) {
    var current = pid
    let runningApps = NSWorkspace.shared.runningApplications
    for _ in 0..<10 {
        let ppidStr = shell("ps -o ppid= -p \(current)").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ppid = Int(ppidStr), ppid > 1 else { break }
        if let app = runningApps.first(where: { $0.processIdentifier == pid_t(ppid) && $0.activationPolicy == .regular }) {
            app.activate()
            return
        }
        current = ppid
    }
}

func waitingLabel(_ type: String) -> String {
    switch type {
    case "permission_prompt": return "approval"
    case "idle_prompt": return "done"
    case "elicitation_dialog": return "question"
    default: return "waiting"
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var prevWaitingCount = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        let processes = getRunningProcesses()
        let waiting = getWaitingInfos()
        let active = processes.filter { $0.cpu > 3.0 }

        if prevWaitingCount == 0 && !waiting.isEmpty {
            NSSound(named: "Ping")?.play()
            flashTitle()
        }
        prevWaitingCount = waiting.count

        statusItem.button?.title = "\(active.count)\u{26A1}\(waiting.count)"

        let menu = NSMenu()

        if !active.isEmpty {
            menu.addItem(NSMenuItem(title: "\u{2014} Active \u{2014}", action: nil, keyEquivalent: ""))
            for p in active {
                let item = NSMenuItem(title: p.project, action: #selector(focusSession(_:)), keyEquivalent: "")
                item.target = self
                item.tag = p.pid
                menu.addItem(item)
            }
        }
        if !waiting.isEmpty {
            menu.addItem(NSMenuItem(title: "\u{2014} Waiting \u{2014}", action: nil, keyEquivalent: ""))
            for w in waiting {
                let pid = processes.first { $0.cwd == w.cwd }?.pid ?? 0
                let item = NSMenuItem(title: "\(w.project) (\(waitingLabel(w.type)))", action: #selector(focusSession(_:)), keyEquivalent: "")
                item.target = self
                item.tag = pid
                menu.addItem(item)
            }
        }
        if active.isEmpty && waiting.isEmpty {
            menu.addItem(NSMenuItem(title: "No sessions", action: nil, keyEquivalent: ""))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func flashTitle() {
        let original = statusItem.button?.title ?? ""
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
            count += 1
            self?.statusItem.button?.title = count % 2 == 0 ? original : ""
            if count >= 6 {
                timer.invalidate()
                self?.statusItem.button?.title = original
            }
        }
    }

    @objc func focusSession(_ sender: NSMenuItem) {
        guard sender.tag > 0 else { return }
        activateTerminal(forPID: sender.tag)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
