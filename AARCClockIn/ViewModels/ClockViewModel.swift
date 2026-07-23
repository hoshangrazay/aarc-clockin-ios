import Foundation
import Combine
import UserNotifications

@MainActor
final class ClockViewModel: ObservableObject {
    enum Screen: Equatable {
        case loading
        case login
        case clock
    }

    struct UIState {
        var screen: Screen = .loading
        var username: String = ""
        var clockedIn: Bool = false
        var durationSeconds: Int = 0
        var locationStatus: LocationStatus = .unknown
        var isSubmitting: Bool = false
        var geofenceRadius: Int = 250
        var lastError: String? = nil
        var clockInTime: Date? = nil
        var geofenceName: String = ""
    }

    @Published var state = UIState()
    @Published var loginUsername: String = ""
    @Published var loginPassword: String = ""
    @Published var loginError: String? = nil

    let session = SessionManager.shared
    let location = LocationService.shared
    let api = ClockApi.shared

    private var durationTimer: Timer?
    private var locationSendTimer: Timer?
    private var statusPollTimer: Timer?
    private var locationCancellable: AnyCancellable?

    init() {
        observeLocation()
    }

    func bootstrap() async {
        if let tok = session.token, !tok.isEmpty {
            state.username = session.username ?? ""
            await refreshStatus()
        } else {
            state.screen = .login
        }
    }

    func login() async {
        guard !loginUsername.isEmpty, !loginPassword.isEmpty else {
            loginError = "Please enter username and password"
            return
        }
        loginError = nil
        state.isSubmitting = true
        defer { state.isSubmitting = false }

        do {
            let resp = try await api.login(username: loginUsername, password: loginPassword)
            if resp.ok, let tok = resp.token {
                session.token = tok
                session.username = resp.username ?? loginUsername
                state.username = session.username ?? loginUsername
                state.lastError = nil
                await refreshStatus()
            } else {
                loginError = resp.msg ?? "Login failed"
            }
        } catch {
            loginError = error.localizedDescription
        }
    }

    func logout() {
        session.logout()
        stopTimers()
        location.stopTracking()
        state.screen = .login
        state.clockedIn = false
        state.durationSeconds = 0
        state.clockInTime = nil
        state.locationStatus = .unknown
        loginPassword = ""
    }

    func refreshStatus() async {
        guard let token = session.token, !token.isEmpty else {
            state.screen = .login
            return
        }
        do {
            let resp = try await api.status(token: token)
            if resp.ok && resp.loggedIn == true {
                session.username = resp.username ?? session.username
                state.username = session.username ?? ""
                state.clockedIn = resp.clockedIn ?? false
                state.geofenceRadius = resp.geofenceRadius ?? 250
                state.geofenceName = ""
                state.lastError = nil
                if state.clockedIn {
                    state.durationSeconds = DurationParser.toSeconds(resp.duration)
                    state.clockInTime = Date().addingTimeInterval(TimeInterval(-state.durationSeconds))
                    location.startTracking()
                    startTimers()
                } else {
                    state.durationSeconds = 0
                    state.clockInTime = nil
                    location.stopTracking()
                    stopTimers()
                }
                state.screen = .clock
            } else {
                session.logout()
                state.screen = .login
                loginError = resp.msg ?? "Session expired. Please log in again."
                loginPassword = ""
                stopTimers()
                location.stopTracking()
            }
        } catch {
            if let apiError = error as? ApiError, case .server(let code) = apiError, code == 401 {
                logout()
                loginError = "Session expired. Please log in again."
            } else {
                state.lastError = error.localizedDescription
                state.screen = .clock
            }
        }
    }

    func toggleClock() async {
        guard let token = session.token, !token.isEmpty else {
            state.screen = .login
            return
        }
        state.isSubmitting = true
        defer { state.isSubmitting = false }

        if state.clockedIn {
            do {
                let resp = try await api.toggle(token: token, lat: nil, lng: nil)
                if resp.ok {
                    state.clockedIn = false
                    state.durationSeconds = 0
                    state.clockInTime = nil
                    state.locationStatus = .unknown
                    stopTimers()
                    location.stopTracking()
                } else {
                    state.lastError = resp.msg ?? "Clock out failed"
                }
            } catch {
                state.lastError = error.localizedDescription
            }
        } else {
            guard location.hasAuthorization else {
                location.requestWhenInUse()
                state.lastError = "Location permission is required to clock in"
                return
            }

            state.lastError = nil
            do {
                let loc = try await location.requestSingle()
                let lat = loc.coordinate.latitude
                let lng = loc.coordinate.longitude

                let check = try await api.checkLocation(token: token, lat: lat, lng: lng)
                location.updateStatusFromCheckLocation(check)
                state.locationStatus = location.status
                state.geofenceRadius = check.radius ?? state.geofenceRadius

                guard check.canClockIn == true else {
                    let d = check.distance ?? 0
                    let r = check.radius ?? state.geofenceRadius
                    state.lastError = "You are \(d)m from the charity. Must be within \(r)m to clock in."
                    return
                }

                let resp = try await api.toggle(token: token, lat: lat, lng: lng)
                if resp.ok {
                    state.clockedIn = true
                    state.durationSeconds = 0
                    state.clockInTime = Date()
                    location.startTracking()
                    startTimers()
                    state.locationStatus = .inside(distanceMeters: check.distance ?? 0)
                    sendTrackingNotification()
                } else {
                    state.lastError = resp.msg ?? "Clock in failed"
                }
            } catch {
                state.lastError = error.localizedDescription
                if (error as? ApiError) != nil {
                    location.markUnavailable()
                    state.locationStatus = .unavailable
                }
            }
        }
    }

    func requestLocationPermission() {
        location.requestWhenInUse()
    }

    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            state.lastError = "Notification permission denied: \(error.localizedDescription)"
        }
    }

    private func sendTrackingNotification() {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "AARC Clock in — Tracking Active"
        content.body = "Location tracking is running. Do NOT swipe this app closed or tracking will stop."
        content.sound = .default
        let req = UNNotificationRequest(identifier: "tracking-warning", content: content, trigger: nil)
        center.add(req)
    }

    private func observeLocation() {
        locationCancellable = location.$lastLocation
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, self.state.clockedIn else { return }
                self.uploadCurrentLocation()
            }
    }

    private func uploadCurrentLocation() {
        guard let token = session.token, let loc = location.lastLocation, state.clockedIn else { return }
        let lat = loc.coordinate.latitude
        let lng = loc.coordinate.longitude
        let acc = loc.horizontalAccuracy
        Task {
            do {
                let resp = try await api.sendLocation(token: token, lat: lat, lng: lng, accuracy: acc)
                location.applyLocationResponse(resp)
                state.locationStatus = location.status
                if resp.action == "geofence_out" {
                    self.handleForcedClockOut(msg: resp.msg)
                }
            } catch {
                print("Location upload failed: \(error)")
            }
        }
    }

    private func handleForcedClockOut(msg: String?) {
        state.clockedIn = false
        state.clockInTime = nil
        state.durationSeconds = 0
        stopTimers()
        location.stopTracking()
        state.locationStatus = .outside(distanceMeters: 0)
        let content = UNMutableNotificationContent()
        content.title = "AARC Clock in"
        content.body = msg ?? "You have been automatically clocked out (left the charity)."
        content.sound = .default
        let req = UNNotificationRequest(identifier: "geofence_out", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
        state.lastError = msg ?? "You left the charity area - automatically clocked out"
    }

    private func startTimers() {
        durationTimer?.invalidate()
        locationSendTimer?.invalidate()
        statusPollTimer?.invalidate()

        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let start = self.state.clockInTime else { return }
                self.state.durationSeconds = Int(Date().timeIntervalSince(start))
            }
        }

        locationSendTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.uploadCurrentLocation()
            }
        }
        Task { @MainActor in
            self.uploadCurrentLocation()
        }

        statusPollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshStatus()
            }
        }
    }

    private func stopTimers() {
        durationTimer?.invalidate()
        locationSendTimer?.invalidate()
        statusPollTimer?.invalidate()
        durationTimer = nil
        locationSendTimer = nil
        statusPollTimer = nil
    }

    deinit {
        durationTimer?.invalidate()
        locationSendTimer?.invalidate()
        statusPollTimer?.invalidate()
    }
}

extension ClockViewModel.UIState: Equatable {
    static func == (lhs: ClockViewModel.UIState, rhs: ClockViewModel.UIState) -> Bool {
        lhs.screen == rhs.screen &&
        lhs.username == rhs.username &&
        lhs.clockedIn == rhs.clockedIn &&
        lhs.durationSeconds == rhs.durationSeconds &&
        lhs.locationStatus == rhs.locationStatus &&
        lhs.isSubmitting == rhs.isSubmitting &&
        lhs.geofenceRadius == rhs.geofenceRadius
    }
}