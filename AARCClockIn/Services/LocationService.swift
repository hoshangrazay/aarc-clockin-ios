import Foundation
import CoreLocation

enum LocationStatus: Equatable {
    case inside(distanceMeters: Int)
    case outside(distanceMeters: Int)
    case unavailable
    case denied
    case unknown

    var label: String {
        switch self {
        case .inside(let d): return "Inside geofence (\(d)m)"
        case .outside(let d): return "Outside geofence (\(d)m)"
        case .unavailable: return "GPS unavailable"
        case .denied: return "Location permission denied"
        case .unknown: return "Locating..."
        }
    }

    var isInside: Bool {
        if case .inside = self { return true }
        return false
    }
}

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?
    @Published var status: LocationStatus = .unknown

    private var pendingContinuation: CheckedContinuation<CLLocation, Error>?
    private var requestTimeout: DispatchWorkItem?

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = false
    }

    var hasAuthorization: Bool {
        let s = manager.authorizationStatus
        return s == .authorizedWhenInUse || s == .authorizedAlways
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }

    func requestSingle() async throws -> CLLocation {
        guard hasAuthorization else {
            throw ApiError.api("Location permission not granted")
        }
        manager.requestLocation()
        return try await withCheckedThrowingContinuation { continuation in
            self.pendingContinuation = continuation
            let timeout = DispatchWorkItem { [weak self] in
                guard let self = self, let pending = self.pendingContinuation else { return }
                self.pendingContinuation = nil
                if let last = self.lastLocation {
                    pending.resume(returning: last)
                } else {
                    pending.resume(throwing: ApiError.network("Location request timed out"))
                }
            }
            self.requestTimeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)
        }
    }

    func startTracking() {
        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
        manager.allowsBackgroundLocationUpdates = (manager.authorizationStatus == .authorizedAlways)
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        requestTimeout?.cancel()
        requestTimeout = nil
        pendingContinuation = nil
        status = .unknown
    }

    func updateStatusFromCheckLocation(_ response: CheckLocationResponse) {
        if response.inside {
            status = .inside(distanceMeters: response.distance)
        } else {
            status = .outside(distanceMeters: response.distance)
        }
    }

    func markDenied() {
        status = .denied
    }

    func markUnavailable() {
        status = .unavailable
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .denied || authorizationStatus == .restricted {
            status = .denied
        } else if authorizationStatus == .notDetermined {
            status = .unknown
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location

        if let pending = pendingContinuation {
            self.pendingContinuation = nil
            self.requestTimeout?.cancel()
            self.requestTimeout = nil
            pending.resume(returning: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let pending = pendingContinuation {
            self.pendingContinuation = nil
            self.requestTimeout?.cancel()
            self.requestTimeout = nil
            pending.resume(throwing: error)
        } else {
            status = .unavailable
        }
    }
}

extension CLAuthorizationStatus {
    var isAuthorized: Bool {
        return self == .authorizedWhenInUse || self == .authorizedAlways
    }
}