# AARC Clock In - iOS

Native iOS app (Swift + SwiftUI) for AARC charity volunteers to clock in/out with GPS geofence verification. Built unsigned via GitHub Actions and sideloaded via 3uTools (until Apple Developer account is ready).

## Stack

- Swift 5.9 + SwiftUI
- iOS 16+ deployment target
- No third-party dependencies (URLSession + Codable + CLLocationManager)
- Built on GitHub Actions (`macos-latest`) via XcodeGen to generate the project
- Unsigned IPA for sideload via 3uTools/AltStore

## User flow

1. App opens - requests location & notification permissions
2. No saved token - login screen (username + password)
3. On login - `GET /api/clock/status` - clock screen
4. Tap "Clock In" - verifies GPS enabled, checks geofence via API, submits clock-in
5. While clocked in - location service sends GPS every 60s, status poll every 30s, duration updates every 1s
6. If server returns `geofence_out` - local notification fired, auto clocked out
7. Tap "Clock Out" - submits request without GPS, stops service

## Backend

- Base URL: `https://www.aarcvisitor.com` (uses `www.` prefix to avoid 301 redirect POST-to-GET issue)
- Auth: `?t=<token>` query param on every request
- Endpoints:
  - `POST /api/clock/login`
  - `GET  /api/clock/status?t=<token>`
  - `POST /api/clock/toggle?t=<token>`
  - `POST /api/clock/location?t=<token>`
  - `POST /api/clock/check-location?t=<token>`

## Project structure

```
AARCClockIn/
  App/AARCClockInApp.swift     - @main entry, permission bootstrap
  Models/ApiModels.swift       - Codable response models
  Networking/
    ClockApi.swift             - URLSession async client
    SessionManager.swift        - UserDefaults token storage
  Services/LocationService.swift - CLLocationManager wrapper
  ViewModels/ClockViewModel.swift - state, timers, orchestration
  Views/
    RootView.swift              - Login <-> Clock switch
    LoginScreen.swift           - username + password form
    ClockScreen.swift          - 200pt circle button, duration, location bar
  Resources/
    Info.plist                 - permissions, background modes
    Assets.xcassets/AppIcon.appiconset/ - 1024x1024 AARC logo
```

## Build (local)

Requires Mac with Xcode 15+ and `brew install xcodegen`:

```bash
xcodegen generate
xcodebuild -project AARCClockIn.xcodeproj -scheme AARCClockIn -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build \
  -derivedDataPath build/
```

## Build (CI)

Any push to `main` triggers `.github/workflows/build-ipa.yml`. Download the `AARCClockIn-unsigned-ipa` artifact from the Actions tab.

## Sideload via 3uTools

1. Download the IPA artifact from the latest run
2. Open 3uTools (Windows)
3. Connect iPhone via USB
4. Go to "Flash & JB" > "IPA signing" or "Install IPA"
5. Select the downloaded IPA, sign with your Apple ID, install

Free Apple IDs give 7-day sideload validity. Re-sign when it expires. When Apple Developer account is approved, submit to App Store for permanent install.

## Permissions (Info.plist)

- `NSLocationWhenInUseUsageDescription` - for geofence check at clock-in
- `NSLocationAlwaysAndWhenInUseUsageDescription` - for background GPS during clocked-in period
- `UIBackgroundModes: [location]` - allows background location updates
- Notifications - requested at runtime via `UNUserNotificationCenter`

## Bundles

- Bundle ID: `com.aarc.aarcclockin`
- Display name: "AARC Clock in"
- Version: 1.0 (build 1)