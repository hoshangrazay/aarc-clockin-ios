import Foundation

struct StatusResponse: Codable {
    let clockedIn: Bool
    let duration: Int
    let username: String?
    let geofence: String?

    enum CodingKeys: String, CodingKey {
        case clockedIn = "clocked_in"
        case duration
        case username
        case geofence
    }
}

struct LoginResponse: Codable {
    let success: Bool
    let token: String?
    let username: String?
    let error: String?
}

struct ToggleResponse: Codable {
    let success: Bool
    let clockedIn: Bool
    let duration: Int
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case clockedIn = "clocked_in"
        case duration
        case message
    }
}

struct LocationResponse: Codable {
    let success: Bool
    let action: String?
}

struct CheckLocationResponse: Codable {
    let inside: Bool
    let distance: Int
    let message: String?
}