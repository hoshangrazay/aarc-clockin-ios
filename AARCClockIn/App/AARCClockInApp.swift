import SwiftUI
import CoreLocation
import UserNotifications

@main
struct AARCClockInApp: App {
    @StateObject private var viewModel = ClockViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
                .onAppear {
                    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
                    Task {
                        await viewModel.requestNotificationPermission()
                        viewModel.requestLocationPermission()
                        await viewModel.bootstrap()
                    }
                }
        }
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}