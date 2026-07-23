import Foundation

class SessionManager {
    static let shared = SessionManager()
    private let defaults = UserDefaults.standard

    var token: String? {
        get { defaults.string(forKey: "token") }
        set { defaults.set(newValue, forKey: "token") }
    }

    var username: String? {
        get { defaults.string(forKey: "username") }
        set { defaults.set(newValue, forKey: "username") }
    }

    func logout() {
        defaults.removeObject(forKey: "token")
        defaults.removeObject(forKey: "username")
        let storage = HTTPCookieStorage.shared
        if let cookies = storage.cookies {
            for cookie in cookies {
                storage.deleteCookie(cookie)
            }
        }
    }
}