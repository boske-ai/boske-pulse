import Foundation
import Network

public struct PrivateNetworkProber: Sendable {
    public init() {}

    public func probe(
        _ probe: PrivateProbe,
        allowedCIDR: String,
        timeoutSeconds: TimeInterval = 5
    ) async -> PrivateProbeResult {
        guard SecurityPolicy.isValidPrivateProbePort(probe.port) else {
            return PrivateProbeResult(id: probe.id, label: probe.label, status: .fail, message: "invalid port")
        }
        guard SecurityPolicy.isAllowedPrivateProbeHost(probe.host, allowedCIDR: allowedCIDR) else {
            return PrivateProbeResult(id: probe.id, label: probe.label, status: .skipped, message: "host outside allowed network")
        }

        await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(probe.host)
            let port = NWEndpoint.Port(rawValue: UInt16(probe.port))!
            let connection = NWConnection(host: host, port: port, using: .tcp)

            let queue = DispatchQueue(label: "eu.canopystudio.boske.pulse.probe.\(probe.id)")
            var finished = false

            func finish(_ result: PrivateProbeResult) {
                guard !finished else { return }
                finished = true
                connection.cancel()
                continuation.resume(returning: result)
            }

            queue.asyncAfter(deadline: .now() + timeoutSeconds) {
                finish(PrivateProbeResult(id: probe.id, label: probe.label, status: .fail, message: "timeout"))
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(PrivateProbeResult(id: probe.id, label: probe.label, status: .ok))
                case .failed(let error):
                    finish(PrivateProbeResult(id: probe.id, label: probe.label, status: .fail, message: error.localizedDescription))
                case .cancelled:
                    break
                default:
                    break
                }
            }

            connection.start(queue: queue)
        }
    }
}
