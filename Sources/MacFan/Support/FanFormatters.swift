import Foundation

enum FanFormatters {
    static func rpm(_ value: Int?) -> String {
        guard let value else { return "-- RPM" }
        return "\(value) RPM"
    }

    static func percentage(_ value: Int) -> String {
        "\(value)%"
    }

    static func updated(_ date: Date?) -> String {
        guard let date else { return "Not refreshed" }
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return "Updated \(formatter.string(from: date))"
    }
}
