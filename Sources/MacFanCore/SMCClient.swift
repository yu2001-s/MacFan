import Darwin
import Foundation
import IOKit

public enum SMCError: LocalizedError {
    case serviceUnavailable(String)
    case connectionClosed
    case invalidKey(String)
    case readFailed(key: String, code: kern_return_t)
    case writeFailed(key: String, code: kern_return_t)
    case unsupportedFanControl(String)

    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable(let message):
            return message
        case .connectionClosed:
            return "SMC connection is closed."
        case .invalidKey(let key):
            return "Invalid SMC key: \(key)"
        case .readFailed(let key, let code):
            return "Read failed for \(key): \(Self.describe(code))"
        case .writeFailed(let key, let code):
            return "Write failed for \(key): \(Self.describe(code))"
        case .unsupportedFanControl(let message):
            return message
        }
    }

    private static func describe(_ code: kern_return_t) -> String {
        guard let cString = mach_error_string(code) else {
            return "unknown error 0x\(String(code, radix: 16))"
        }
        return "\(String(cString: cString)) 0x\(String(code, radix: 16))"
    }
}

private enum SMCDataType: String {
    case ui8 = "ui8 "
    case ui16 = "ui16"
    case ui32 = "ui32"
    case sp1e = "sp1e"
    case sp3c = "sp3c"
    case sp4b = "sp4b"
    case sp5a = "sp5a"
    case spa5 = "spa5"
    case sp69 = "sp69"
    case sp78 = "sp78"
    case sp87 = "sp87"
    case sp96 = "sp96"
    case spb4 = "spb4"
    case spf0 = "spf0"
    case flt = "flt "
    case fpe2 = "fpe2"
    case fds = "{fds"
}

private enum SMCCommand: UInt8 {
    case kernelIndex = 2
    case readBytes = 5
    case writeBytes = 6
    case readIndex = 8
    case readKeyInfo = 9
}

private struct SMCKeyData {
    typealias SMCBytes = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    struct Version {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct LimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyInfo {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = Version()
    var pLimitData = LimitData()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = SMCKeyData.emptyBytes

    static let emptyBytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

private struct SMCValue {
    var key: String
    var dataSize: UInt32 = 0
    var dataType: String = ""
    var bytes: [UInt8] = Array(repeating: 0, count: 32)

    init(_ key: String) {
        self.key = key
    }
}

public final class SMCClient {
    private var connection: io_connect_t = 0
    private var fanModeKeyIsLowercase: Bool?

    public init() throws {
        var iterator: io_iterator_t = 0
        let matchingDictionary = IOServiceMatching("AppleSMC")
        let matchingResult = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator)

        guard matchingResult == kIOReturnSuccess else {
            throw SMCError.serviceUnavailable("AppleSMC service lookup failed: \(matchingResult)")
        }

        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)

        guard device != 0 else {
            throw SMCError.serviceUnavailable("AppleSMC service was not found on this Mac.")
        }

        let openResult = IOServiceOpen(device, mach_task_self_, 0, &connection)
        IOObjectRelease(device)

        guard openResult == kIOReturnSuccess else {
            throw SMCError.serviceUnavailable("AppleSMC open failed: \(openResult)")
        }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    public func readFans() throws -> [FanInfo] {
        guard let countValue = try getDouble("FNum") else {
            throw SMCError.unsupportedFanControl("No SMC fan count key was found.")
        }

        let count = max(0, Int(countValue))
        guard count > 0 else {
            return []
        }

        return (0..<count).map { id in
            let name = (try? getString("F\(id)ID")) ?? "Fan \(id + 1)"
            let current = Int((try? getDouble("F\(id)Ac")) ?? 0)
            let minimum = Int((try? getDouble("F\(id)Mn")) ?? 0)
            let maximum = Int((try? getDouble("F\(id)Mx")) ?? 0)
            let target = (try? getDouble("F\(id)Tg")).map { Int($0) }
            let modeRaw = Int((try? getDouble(fanModeKey(id))) ?? 0)
            let mode = FanMode(rawValue: modeRaw) ?? .automatic

            return FanInfo(
                id: id,
                name: name,
                currentRPM: current,
                minimumRPM: minimum,
                maximumRPM: maximum,
                targetRPM: target,
                mode: mode
            )
        }
    }

    public func setFanMode(_ id: Int, mode: FanMode) throws {
        #if arch(arm64)
        if mode == .forced {
            try unlockFanControl(fanID: id)
            return
        }

        let modeKey = fanModeKey(id)
        var modeValue = try readValue(modeKey)
        if modeValue.bytes[0] != 0 {
            modeValue.bytes[0] = 0
            try writeWithRetry(modeValue)
        }

        if var targetValue = try? readValue("F\(id)Tg") {
            targetValue.applyFloat(0)
            try writeWithRetry(targetValue)
        }

        try disableFanTestModeIfAllFansAutomatic()
        #else
        if var modeValue = try? readValue("F\(id)Md") {
            modeValue.bytes = SMCValue.bytes(first: UInt8(mode.rawValue))
            try write(modeValue)
        }

        let fansMode = Int((try? getDouble("FS! ")) ?? 0)
        var newMode: UInt8 = UInt8(fansMode)

        if fansMode == 0 && id == 0 && mode == .forced {
            newMode = 1
        } else if fansMode == 0 && id == 1 && mode == .forced {
            newMode = 2
        } else if fansMode == 1 && id == 0 && mode.isAutomatic {
            newMode = 0
        } else if fansMode == 1 && id == 1 && mode == .forced {
            newMode = 3
        } else if fansMode == 2 && id == 1 && mode.isAutomatic {
            newMode = 0
        } else if fansMode == 2 && id == 0 && mode == .forced {
            newMode = 3
        } else if fansMode == 3 && id == 0 && mode.isAutomatic {
            newMode = 2
        } else if fansMode == 3 && id == 1 && mode.isAutomatic {
            newMode = 1
        }

        guard fansMode != Int(newMode) else {
            return
        }

        var value = try readValue("FS! ")
        value.bytes = SMCValue.bytes(first: 0, second: newMode)
        try write(value)
        #endif
    }

    public func setFanSpeed(_ id: Int, rpm: Int) throws {
        let minimum = Int((try? getDouble("F\(id)Mn")) ?? 0)
        let maximum = Int((try? getDouble("F\(id)Mx")) ?? Double(rpm))
        let sanitizedRPM = rpm.clamped(to: minimum...max(maximum, minimum))

        #if arch(arm64)
        let modeKey = fanModeKey(id)
        let modeValue = try readValue(modeKey)
        if modeValue.bytes[0] != 1 {
            try unlockFanControl(fanID: id)
        }
        #endif

        var targetValue = try readValue("F\(id)Tg")
        switch targetValue.dataType {
        case SMCDataType.flt.rawValue:
            targetValue.applyFloat(Float(sanitizedRPM))
        case SMCDataType.fpe2.rawValue:
            targetValue.applyFPE2(sanitizedRPM)
        default:
            throw SMCError.unsupportedFanControl("Unsupported target speed type \(targetValue.dataType) for fan \(id + 1).")
        }

        #if arch(arm64)
        try writeWithRetry(targetValue)
        #else
        try write(targetValue)
        #endif
    }

    public func resetFanControl() throws {
        #if arch(arm64)
        if var ftst = try? readValue("Ftst"), ftst.dataSize > 0 {
            if ftst.bytes[0] == 0 {
                return
            }
            ftst.bytes[0] = 0
            try writeWithRetry(ftst)
            return
        }
        #endif

        guard let countValue = try getDouble("FNum") else {
            throw SMCError.unsupportedFanControl("No SMC fan count key was found.")
        }

        for id in 0..<Int(countValue) {
            try setFanMode(id, mode: .automatic)
        }
    }

    private func getDouble(_ key: String) throws -> Double? {
        let value = try readValue(key)

        guard value.dataSize > 0 else {
            return nil
        }

        if value.bytes.first(where: { $0 != 0 }) == nil,
           key != "FS! ",
           key != "F0Md",
           key != "F1Md",
           key != "F0md",
           key != "F1md" {
            return nil
        }

        switch value.dataType {
        case SMCDataType.ui8.rawValue:
            return Double(value.bytes[0])
        case SMCDataType.ui16.rawValue:
            return Double(UInt16(bigEndianBytes: (value.bytes[0], value.bytes[1])))
        case SMCDataType.ui32.rawValue:
            return Double(UInt32(bigEndianBytes: (value.bytes[0], value.bytes[1], value.bytes[2], value.bytes[3])))
        case SMCDataType.sp1e.rawValue:
            return Double(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1])) / 16_384
        case SMCDataType.sp3c.rawValue:
            return Double(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1])) / 4_096
        case SMCDataType.sp4b.rawValue:
            return Double(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1])) / 2_048
        case SMCDataType.sp5a.rawValue:
            return Double(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1])) / 1_024
        case SMCDataType.sp69.rawValue:
            return Double(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1])) / 512
        case SMCDataType.sp78.rawValue:
            return Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1])) / 256
        case SMCDataType.sp87.rawValue:
            return Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1])) / 128
        case SMCDataType.sp96.rawValue:
            return Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1])) / 64
        case SMCDataType.spa5.rawValue:
            return Double(UInt16(value.bytes[0]) * 256 + UInt16(value.bytes[1])) / 32
        case SMCDataType.spb4.rawValue:
            return Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1])) / 16
        case SMCDataType.spf0.rawValue:
            return Double(Int(value.bytes[0]) * 256 + Int(value.bytes[1]))
        case SMCDataType.flt.rawValue:
            return Double(Float(smcBytes: value.bytes))
        case SMCDataType.fpe2.rawValue:
            return Double(Int(fpe2Bytes: (value.bytes[0], value.bytes[1])))
        default:
            return nil
        }
    }

    private func getString(_ key: String) throws -> String? {
        let value = try readValue(key)

        guard value.dataSize > 0,
              value.bytes.first(where: { $0 != 0 }) != nil,
              value.dataType == SMCDataType.fds.rawValue else {
            return nil
        }

        let nameScalars = value.bytes[4..<min(16, value.bytes.count)].compactMap { byte -> UnicodeScalar? in
            guard byte != 0 else { return nil }
            return UnicodeScalar(byte)
        }

        let name = String(String.UnicodeScalarView(nameScalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private func fanModeKey(_ id: Int) -> String {
        #if arch(arm64)
        if fanModeKeyIsLowercase == nil {
            var probe = SMCValue("F0md")
            fanModeKeyIsLowercase = ((try? read(&probe)) != nil) && probe.dataSize > 0
        }
        return fanModeKeyIsLowercase == true ? "F\(id)md" : "F\(id)Md"
        #else
        return "F\(id)Md"
        #endif
    }

    #if arch(arm64)
    private func unlockFanControl(fanID: Int) throws {
        let modeKey = fanModeKey(fanID)
        var modeValue = try readValue(modeKey)
        modeValue.bytes[0] = 1

        if writeRaw(modeValue) == kIOReturnSuccess {
            return
        }

        guard var ftst = try? readValue("Ftst"), ftst.dataSize > 0 else {
            throw SMCError.unsupportedFanControl("Fan control unlock was rejected by SMC.")
        }

        if ftst.bytes[0] == 1 {
            try retryModeWrite(fanID: fanID, maxAttempts: 20)
            return
        }

        ftst.bytes[0] = 1
        try writeWithRetry(ftst, maxAttempts: 100)

        // thermalmonitord needs a moment to yield manual fan control on Apple Silicon.
        usleep(3_000_000)
        try retryModeWrite(fanID: fanID, maxAttempts: 300)
    }

    private func retryModeWrite(fanID: Int, maxAttempts: Int) throws {
        let modeKey = fanModeKey(fanID)
        var modeValue = try readValue(modeKey)
        modeValue.bytes[0] = 1
        try writeWithRetry(modeValue, maxAttempts: maxAttempts, delayMicros: 100_000)
    }

    private func disableFanTestModeIfAllFansAutomatic() throws {
        guard var ftst = try? readValue("Ftst"), ftst.dataSize > 0 else {
            return
        }

        guard let countValue = try getDouble("FNum") else {
            return
        }

        for id in 0..<Int(countValue) {
            let modeValue = try readValue(fanModeKey(id))
            if modeValue.bytes[0] == FanMode.forced.rawValue {
                return
            }
        }

        if ftst.bytes[0] != 0 {
            ftst.bytes[0] = 0
            try writeWithRetry(ftst)
        }
    }
    #endif

    private func readValue(_ key: String) throws -> SMCValue {
        var value = SMCValue(key)
        try read(&value)
        return value
    }

    private func read(_ value: inout SMCValue) throws {
        guard connection != 0 else {
            throw SMCError.connectionClosed
        }

        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = try UInt32(smcKey: value.key)
        input.data8 = SMCCommand.readKeyInfo.rawValue

        var result = call(SMCCommand.kernelIndex.rawValue, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            throw SMCError.readFailed(key: value.key, code: result)
        }

        value.dataSize = UInt32(output.keyInfo.dataSize)
        value.dataType = output.keyInfo.dataType.smcString

        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = SMCCommand.readBytes.rawValue

        result = call(SMCCommand.kernelIndex.rawValue, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            throw SMCError.readFailed(key: value.key, code: result)
        }

        let outputBytes = output.byteArray
        for index in 0..<min(Int(value.dataSize), value.bytes.count, outputBytes.count) {
            value.bytes[index] = outputBytes[index]
        }
    }

    private func write(_ value: SMCValue) throws {
        let result = writeRaw(value)
        guard result == kIOReturnSuccess else {
            throw SMCError.writeFailed(key: value.key, code: result)
        }
    }

    private func writeWithRetry(
        _ value: SMCValue,
        maxAttempts: Int = 10,
        delayMicros: UInt32 = 50_000
    ) throws {
        var lastResult: kern_return_t = kIOReturnSuccess

        for attempt in 0..<maxAttempts {
            lastResult = writeRaw(value)
            if lastResult == kIOReturnSuccess {
                return
            }

            if attempt < maxAttempts - 1 {
                usleep(delayMicros)
            }
        }

        throw SMCError.writeFailed(key: value.key, code: lastResult)
    }

    private func writeRaw(_ value: SMCValue) -> kern_return_t {
        guard connection != 0 else {
            return kIOReturnNotOpen
        }

        var input = SMCKeyData()
        var output = SMCKeyData()

        do {
            input.key = try UInt32(smcKey: value.key)
        } catch {
            return kIOReturnBadArgument
        }

        input.data8 = SMCCommand.writeBytes.rawValue
        input.keyInfo.dataSize = IOByteCount32(value.dataSize)
        input.bytes = SMCKeyData.bytes(from: value.bytes)

        let result = call(SMCCommand.kernelIndex.rawValue, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            return result
        }

        return output.result == 0x00 ? kIOReturnSuccess : kIOReturnError
    }

    private func call(_ index: UInt8, input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride
        return IOConnectCallStructMethod(connection, UInt32(index), &input, inputSize, &output, &outputSize)
    }
}

private extension SMCKeyData {
    var byteArray: [UInt8] {
        [
            bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5, bytes.6, bytes.7,
            bytes.8, bytes.9, bytes.10, bytes.11, bytes.12, bytes.13, bytes.14, bytes.15,
            bytes.16, bytes.17, bytes.18, bytes.19, bytes.20, bytes.21, bytes.22, bytes.23,
            bytes.24, bytes.25, bytes.26, bytes.27, bytes.28, bytes.29, bytes.30, bytes.31
        ]
    }

    static func bytes(from source: [UInt8]) -> SMCBytes {
        let padded = source + Array(repeating: 0, count: max(0, 32 - source.count))
        return (
            padded[0], padded[1], padded[2], padded[3], padded[4], padded[5], padded[6], padded[7],
            padded[8], padded[9], padded[10], padded[11], padded[12], padded[13], padded[14], padded[15],
            padded[16], padded[17], padded[18], padded[19], padded[20], padded[21], padded[22], padded[23],
            padded[24], padded[25], padded[26], padded[27], padded[28], padded[29], padded[30], padded[31]
        )
    }
}

private extension SMCValue {
    static func bytes(first: UInt8, second: UInt8 = 0) -> [UInt8] {
        [first, second] + Array(repeating: 0, count: 30)
    }

    mutating func applyFloat(_ value: Float) {
        let floatBytes = value.smcBytes
        bytes[0] = floatBytes[0]
        bytes[1] = floatBytes[1]
        bytes[2] = floatBytes[2]
        bytes[3] = floatBytes[3]
    }

    mutating func applyFPE2(_ value: Int) {
        bytes[0] = UInt8(value >> 6)
        bytes[1] = UInt8((value << 2) ^ ((value >> 6) << 8))
        bytes[2] = 0
        bytes[3] = 0
    }
}

private extension UInt16 {
    init(bigEndianBytes bytes: (UInt8, UInt8)) {
        self = UInt16(bytes.0) << 8 | UInt16(bytes.1)
    }
}

private extension UInt32 {
    init(smcKey key: String) throws {
        guard key.utf8.count == 4 else {
            throw SMCError.invalidKey(key)
        }

        self = key.utf8.reduce(0) { result, byte in
            result << 8 | UInt32(byte)
        }
    }

    init(bigEndianBytes bytes: (UInt8, UInt8, UInt8, UInt8)) {
        self = UInt32(bytes.0) << 24 | UInt32(bytes.1) << 16 | UInt32(bytes.2) << 8 | UInt32(bytes.3)
    }

    var smcString: String {
        let scalars = [
            UInt8((self >> 24) & 0xff),
            UInt8((self >> 16) & 0xff),
            UInt8((self >> 8) & 0xff),
            UInt8(self & 0xff)
        ].compactMap { UnicodeScalar($0) }

        return String(String.UnicodeScalarView(scalars))
    }
}

private extension Int {
    init(fpe2Bytes bytes: (UInt8, UInt8)) {
        self = (Int(bytes.0) << 6) + (Int(bytes.1) >> 2)
    }
}

private extension Float {
    init(smcBytes bytes: [UInt8]) {
        let raw = UInt32(bytes[0]) |
            UInt32(bytes[1]) << 8 |
            UInt32(bytes[2]) << 16 |
            UInt32(bytes[3]) << 24
        self = Float(bitPattern: raw)
    }

    var smcBytes: [UInt8] {
        let raw = bitPattern
        return [
            UInt8(raw & 0xff),
            UInt8((raw >> 8) & 0xff),
            UInt8((raw >> 16) & 0xff),
            UInt8((raw >> 24) & 0xff)
        ]
    }
}
