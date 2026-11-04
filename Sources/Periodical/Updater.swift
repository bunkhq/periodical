import AppKit
import PeriodicalCore

/// Manual updates from GitHub Releases: "Check for Updates…" in the right-click menu looks up the latest
/// release and, if it's newer, downloads its `.zip`, swaps the app bundle in place, and relaunches.
/// Nothing runs in the background; the network is only touched when the user asks.
@MainActor
final class Updater {
    enum State: Equatable {
        case idle, checking, downloading
    }

    private(set) var state = State.idle

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/bunkhq/periodical/releases/latest")!

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let html_url: URL
        let assets: [Asset]
    }

    private struct UpdateError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    private var currentVersion: AppVersion? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)
    }

    func checkForUpdates() {
        guard state == .idle else { return }
        state = .checking
        Task {
            defer { state = .idle }
            do {
                let release = try await fetchLatestRelease()
                try await offer(release)
            } catch {
                showAlert("Couldn't update Periodical", error.localizedDescription)
            }
        }
    }

    private func fetchLatestRelease() async throws -> Release {
        var request = URLRequest(url: Self.latestReleaseURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UpdateError("Couldn't reach GitHub. Check your internet connection and try again.")
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw UpdateError("Couldn't find any Periodical releases (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)).")
        }
        do {
            return try JSONDecoder().decode(Release.self, from: data)
        } catch {
            throw UpdateError("GitHub sent a release Periodical couldn't read.")
        }
    }

    private func offer(_ release: Release) async throws {
        guard let latest = AppVersion(release.tag_name) else {
            throw UpdateError("The latest release has an unrecognized version (\(release.tag_name)).")
        }
        let current = currentVersion
        if let current, latest <= current {
            showAlert("You're up to date", "Periodical \(current) is the latest version.")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Periodical \(latest) is available"
        alert.informativeText = "You have \(current?.description ?? "an unknown version"). "
            + "Periodical will quit, update, and reopen."
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Release Notes")
        NSApp.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            break
        case .alertThirdButtonReturn:
            NSWorkspace.shared.open(release.html_url)
            return
        default:
            return
        }

        guard let zip = release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
            // Nothing we can install in place, so hand off to the release page's DMG.
            NSWorkspace.shared.open(release.html_url)
            return
        }
        state = .downloading
        try await install(from: zip.browser_download_url, expecting: latest)
    }

    /// Downloads and unpacks the new app next to the current one, then hands the swap to a shell script
    /// that waits for this process to exit, replaces the bundle, and relaunches it.
    private func install(from url: URL, expecting version: AppVersion) async throws {
        let appURL = Bundle.main.bundleURL
        let fm = FileManager.default
        if appURL.path.contains("/AppTranslocation/") {
            throw UpdateError("Move Periodical to your Applications folder, open it from there, and try again.")
        }
        guard fm.isWritableFile(atPath: appURL.deletingLastPathComponent().path),
              fm.isWritableFile(atPath: appURL.path) else {
            throw UpdateError("Periodical can't replace itself at \(appURL.path). Download the new version from the release page instead.")
        }

        // Same volume as the app, so the final swap is a rename rather than a copy.
        let work = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: appURL, create: true)
        var handedOff = false
        defer { if !handedOff { try? fm.removeItem(at: work) } }

        let downloaded: URL
        do {
            (downloaded, _) = try await URLSession.shared.download(from: url)
        } catch {
            throw UpdateError("The download didn't finish. Try again in a moment.")
        }
        let zip = work.appendingPathComponent("update.zip")
        try fm.moveItem(at: downloaded, to: zip)

        let unpacked = work.appendingPathComponent("unpacked", isDirectory: true)
        try run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path])

        let newApp = unpacked.appendingPathComponent(appURL.lastPathComponent)
        guard let bundle = Bundle(url: newApp),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              let newVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init),
              newVersion == version else {
            throw UpdateError("The downloaded update doesn't look like Periodical \(version).")
        }
        // Files fetched by URLSession aren't quarantined, but strip it in case the zip carried the attribute inside.
        try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

        let script = """
            pid="$1"; new="$2"; dest="$3"; work="$4"
            for _ in $(seq 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.2; done
            if mv "$dest" "$work/old.app"; then
                if mv "$new" "$dest"; then rm -rf "$work/old.app"; else mv "$work/old.app" "$dest"; fi
            fi
            open "$dest"
            rm -rf "$work"
            """
        let swap = Process()
        swap.executableURL = URL(fileURLWithPath: "/bin/sh")
        swap.arguments = ["-c", script, "periodical-update",
                          String(ProcessInfo.processInfo.processIdentifier), newApp.path, appURL.path, work.path]
        try swap.run()
        handedOff = true
        NSApp.terminate(nil)
    }

    private func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError("Couldn't unpack the update (\(URL(fileURLWithPath: tool).lastPathComponent) exited with \(process.terminationStatus)).")
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate()
        alert.runModal()
    }
}
