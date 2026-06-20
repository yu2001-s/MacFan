import Foundation
import MacFanCore

protocol FanManaging {
    func readFans() throws -> [FanInfo]
    func setFanMode(id: Int, mode: FanMode) throws
    func setFanSpeed(id: Int, rpm: Int) throws
    func resetFanControl() throws
}

final class SMCFanService: FanManaging {
    private var client: SMCClient?
    private let authorizedTool = AuthorizedToolRunner()

    func readFans() throws -> [FanInfo] {
        try smc().readFans()
    }

    func setFanMode(id: Int, mode: FanMode) throws {
        try authorizedTool.run(arguments: [
            "set-mode",
            "--id", "\(id)",
            "--mode", "\(mode.rawValue)"
        ])
    }

    func setFanSpeed(id: Int, rpm: Int) throws {
        try authorizedTool.run(arguments: [
            "set-speed",
            "--id", "\(id)",
            "--rpm", "\(rpm)"
        ])
    }

    func resetFanControl() throws {
        try authorizedTool.run(arguments: ["reset"])
    }

    private func smc() throws -> SMCClient {
        if let client {
            return client
        }

        let client = try SMCClient()
        self.client = client
        return client
    }
}
