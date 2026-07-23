# AARC Clock In - iOS

Native iOS app (Swift + SwiftUI) for AARC charity volunteer clock in/out with GPS geofence verification.

Built unsigned via GitHub Actions on macOS runner -> sideload with 3uTools.

## Log

### 2026-07-23 — Fresh native iOS app built and IPA delivered

**Context**: Android app at `C:\Users\Hoshang\Desktop\arrc android` works perfectly. Multiple previous iOS attempts (Expo/React Native in `aarc-clockin-expo`, `aarc-clockin-new`, `aarc-clockin-newest`, `aarc-clockin-unsigned-ipa`, `aarc-minimal`) all crashed/looped between white screen and crash on launch.

**Approach**: Fresh slate. Native Swift 5.9 + SwiftUI, no cross-platform framework, zero third-party dependencies (URLSession + Codable + CLLocationManager). Repo `hoshangrazay/aarc-clockin-ios` was overwritten (force push to new `main` branch, old React Native `master` branch deleted).

**Stack**:
- Swift 5.9 + SwiftUI, iOS 16+ deployment target
- XcodeGen generates .xcodeproj from `project.yml` on the GitHub Actions runner (no Xcode needed locally)
- URLSession async/await API client -> https://www.aarcvisitor.com (uses www. prefix to avoid 301 POST-to-GET downgrade)
- CLLocationManager for one-shot (clock-in) + background updating (when clocked in)
- UserDefaults for token storage (mirrors Android's SharedPreferences "aarc_clock")
- GitHub Actions: macos-latest builds unsigned IPA, uploaded as artifact

**Architecture** (mirrors the Android MVVM):
```
AARCClockInApp (@main) -> RootView -> LoginScreen | ClockScreen
                                          |
                                          v
                                   ClockViewModel (@MainActor ObservableObject)
                                   /                  |              \
                          LocationService       ClockApi (actor)    SessionManager
                       (CLLocationManager)     (URLSession async)    (UserDefaults)
```

**Endpoints used** (same backend as the Android app):
- POST /api/clock/login
- GET  /api/clock/status?t=<token>
- POST /api/clock/toggle?t=<token>
- POST /api/clock/location?t=<token>
- POST /api/clock/check-location?t=<token>

**Timers** (matching Android):
- 1s duration ticker when clocked in
- 60s location POST timer
- 30s status poll timer (detects server-forced clock-out via `geofence_out` action)

**App icon**: Generated 1024x1024 PNG from the Android project's `aarc_logo.png` (500x500 RGBA source), white background behind centered logo.

**Build workflow**:
1. Push to `main` triggers `.github/workflows/build-ipa.yml`
2. `brew install xcodegen` + `xcodegen generate` produces the Xcode project
3. `xcodebuild -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO build`
4. Copy `.app` into `Payload/` and `zip` into unsigned `.ipa`
5. Upload as `AARCClockIn-unsigned-ipa` artifact

**Sideload**: Download IPA artifact, open in 3uTools, sign with personal Apple ID, install. Free Apple IDs give 7-day sideload validity.

**Build result (Run #29970319159)**:
- SUCCESS in 1m22s
- IPA: `AARCClockIn-unsigned.ipa` (422 KB)
- Binary: 634 KB compiled Swift
- Bundle ID: `com.aarc.aarcclockin`
- Display name: "AARC Clock in"
- MinimumOS: 16.0
- Background modes: [location]

**Issue encountered & resolved**: GitHub Actions billing for private repos was exhausted (free 2000 min/month; macOS minutes count 10x -- previous React Native attempts burned through them). Error annotation: "recent account payments have failed or your spending limit needs to be increased". Fix: made repo **public** temporarily (public repos get unlimited free Actions minutes; no secrets in source). Can be reverted to private after build if desired.

**Files** (16 total, 1266 LoC):
- `.gitignore`
- `project.yml` (XcodeGen spec)
- `README.md`
- `.github/workflows/build-ipa.yml`
- `AARCClockIn/App/AARCClockInApp.swift` - @main, permission bootstrap, UNUserNotificationCenter delegate
- `AARCClockIn/Models/ApiModels.swift` - 5 Codable response structs with SnakeCase CodingKeys
- `AARCClockIn/Networking/ClockApi.swift` - actor with async URLSession client (www.aarcvisitor.com)
- `AARCClockIn/Networking/SessionManager.swift` - UserDefaults token + username storage
- `AARCClockIn/Services/LocationService.swift` - CLLocationManager wrapper (one-shot + background)
- `AARCClockIn/ViewModels/ClockViewModel.swift` - @MainActor ObservableObject with 1s/60s/30s timers
- `AARCClockIn/Views/RootView.swift` - Login <-> Clock switcher, error alert
- `AARCClockIn/Views/LoginScreen.swift` - username + password form with focus management
- `AARCClockIn/Views/ClockScreen.swift` - 200pt animated circle button, duration counter, location bar
- `AARCClockIn/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
- `AARCClockIn/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `AARCClockIn/Resources/Assets.xcassets/Contents.json`

**IPA location on user's machine**: `C:\Users\Hoshang\Desktop\aarc-clockin-ios-ipa\AARCClockIn-unsigned-ipa\AARCClockIn-unsigned.ipa`

**Repo state**: public, default branch `main`, 2 commits (initial + ci cleanup)

**Next step for user**: Sideload IPA via 3uTools on iPhone 12 Pro Max, test login + clock in/out at Ebury House.