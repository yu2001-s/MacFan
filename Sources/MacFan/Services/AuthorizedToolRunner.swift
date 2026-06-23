import Foundation

enum AuthorizedToolError: LocalizedError {
    case missingTool(URL)
    case launchFailed(String)
    case installFailed(String)
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .missingTool(let url):
            return "The bundled fan control tool was not found at \(url.path)."
        case .launchFailed(let message):
            return "Could not start fan control helper: \(message)"
        case .installFailed(let message):
            return "Could not install fan control helper: \(message)"
        case .rejected(let message):
            return message.isEmpty ? "The fan control command was rejected." : message
        }
    }
}

final class AuthorizedToolRunner {
    private let fileManager = FileManager.default
    private let installedToolURL = URL(fileURLWithPath: "/Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl")
    private let requiredToolVersion = "0.2.1"

    func run(arguments: [String]) throws {
        let toolURL = try ensureInstalledTool()

        let process = Process()
        process.executableURL = toolURL
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw AuthorizedToolError.launchFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        let output = outputPipe.readText()
        let error = errorPipe.readText()

        guard process.terminationStatus == 0 else {
            let message = [error, output]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? "Administrator authorization failed."
            throw AuthorizedToolError.rejected(message)
        }
    }

    private func ensureInstalledTool() throws -> URL {
        let bundledToolURL = try resolvedBundledToolURL()

        if installedToolIsUsable() {
            return installedToolURL
        }

        try installTool(bundledToolURL)

        if installedToolIsUsable() {
            return installedToolURL
        }

        throw AuthorizedToolError.installFailed("The installed helper did not match the bundled helper after installation.")
    }

    private func resolvedBundledToolURL() throws -> URL {
        let bundleTool = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Helpers")
            .appendingPathComponent("macfanctl")

        if fileManager.isExecutableFile(atPath: bundleTool.path) {
            return bundleTool
        }

        if let executableURL = Bundle.main.executableURL {
            let siblingTool = executableURL.deletingLastPathComponent().appendingPathComponent("macfanctl")
            if fileManager.isExecutableFile(atPath: siblingTool.path) {
                return siblingTool
            }
        }

        throw AuthorizedToolError.missingTool(bundleTool)
    }

    private func installedToolIsUsable() -> Bool {
        fileManager.isExecutableFile(atPath: installedToolURL.path) &&
            installedToolHasSetUIDBit() &&
            installedToolVersion() == requiredToolVersion
    }

    private func installedToolHasSetUIDBit() -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: installedToolURL.path),
              let permissions = attributes[.posixPermissions] as? NSNumber else {
            return false
        }

        return permissions.intValue & 0o4000 != 0
    }

    private func installTool(_ bundledToolURL: URL) throws {
        let installCommand = [
            "/bin/mkdir -p /Library/PrivilegedHelperTools",
            "/usr/bin/install -o root -g wheel -m 4755 \(bundledToolURL.path.shellQuoted) \(installedToolURL.path.shellQuoted)"
        ].joined(separator: " && ")
        let script = "do shell script \(installCommand.appleScriptLiteral) with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw AuthorizedToolError.installFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = outputPipe.readText()
            let error = errorPipe.readText()
            let message = [error, output]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? "Administrator authorization failed."
            throw AuthorizedToolError.installFailed(message)
        }
    }

    private func installedToolVersion() -> String? {
        let process = Process()
        process.executableURL = installedToolURL
        process.arguments = ["version"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        return outputPipe.readText().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Pipe {
    func readText() -> String {
        fileHandleForReading.readDataToEndOfFile().stringValue
    }
}

private extension Data {
    var stringValue: String {
        String(data: self, encoding: .utf8) ?? ""
    }
}

private extension String {
    var shellQuoted: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    var appleScriptLiteral: String {
        "\"" + replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
