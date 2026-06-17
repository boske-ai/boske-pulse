import BoskePulseCore
import Foundation

/// Uses `tailscale status --json` when the Tailscale CLI is installed on the Mac.
struct TailscaleCLIReachability: TailscaleReachability {
    func isConnected() async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/tailscale")
            if !FileManager.default.fileExists(atPath: process.executableURL!.path) {
                process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/tailscale")
            }
            guard FileManager.default.fileExists(atPath: process.executableURL!.path) else {
                continuation.resume(returning: false)
                return
            }
            process.arguments = ["status", "--json"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let backendState = json["BackendState"] as? String
                else {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: backendState == "Running")
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
