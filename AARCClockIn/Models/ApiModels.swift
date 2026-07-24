import Foundation

struct HistoryDay: Codable, Identifiable {
    var id: String { date + (clockIn ?? "") }
    let date: String
    let clockIn: String?
    let clockOut: String?
    let duration: String?
    let method: String?

    enum CodingKeys: String, CodingKey {
        case date
        case clockIn = "clock_in"
        case clockOut = "clock_out"
        case duration
        case method
    }
}

struct HistoryResponse: Codable {
    let ok: Bool
    let totalTime: String?
    let totalDays: Int?
    let history: [HistoryDay]?
    let msg: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case totalTime = "total_time"
        case totalDays = "total_days"
        case history
        case msg
    }
}

struct LastEvent: Codable {
    let inTime: String?
    let out: String?
    let method: String?

    enum CodingKeys: String, CodingKey {
        case inTime = "in"
        case out
        case method
    }
}

struct StatusResponse: Codable {
    let ok: Bool
    let loggedIn: Bool?
    let clockedIn: Bool?
    let username: String?
    let clockInTime: String?
    let clockInTs: Double?
    let duration: String?
    let geofenceRadius: Int?
    let lastEvent: LastEvent?
    let msg: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case loggedIn = "logged_in"
        case clockedIn = "clocked_in"
        case username
        case clockInTime = "clock_in_time"
        case clockInTs = "clock_in_ts"
        case duration
        case geofenceRadius = "geofence_radius"
        case lastEvent = "last_event"
        case msg
    }
}

struct LoginResponse: Codable {
    let ok: Bool
    let token: String?
    let username: String?
    let role: String?
    let msg: String?
}

struct ToggleResponse: Codable {
    let ok: Bool
    let action: String?
    let msg: String?
    let time: String?
    let eventId: Int?
    let duration: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case action
        case msg
        case time
        case eventId = "event_id"
        case duration
    }
}

struct LocationResponse: Codable {
    let ok: Bool
    let action: String?
    let distance: Int?
    let inside: Bool?
    let msg: String?
    let duration: String?
}

struct CheckLocationResponse: Codable {
    let ok: Bool
    let inside: Bool?
    let distance: Int?
    let radius: Int?
    let canClockIn: Bool?
    let msg: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case inside
        case distance
        case radius
        case canClockIn = "can_clock_in"
        case msg
    }
}

enum DurationParser {
    static func toSeconds(_ formatted: String?) -> Int {
        guard let s = formatted, !s.isEmpty else { return 0 }
        let pattern = "([0-9]+)\\s*([hms])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return 0 }
        let nsr = s as NSString
        var total = 0
        for match in regex.matches(in: s, range: NSRange(location: 0, length: nsr.length)) {
            let n = Int(nsr.substring(with: match.range(at: 1))) ?? 0
            let u = nsr.substring(with: match.range(at: 2)).lowercased()
            switch u {
            case "h": total += n * 3600
            case "m": total += n * 60
            case "s": total += n
            default: break
            }
        }
        return total
    }
}