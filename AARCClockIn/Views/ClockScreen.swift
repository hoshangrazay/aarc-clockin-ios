import SwiftUI
import CoreLocation

struct ClockScreen: View {
    @EnvironmentObject var viewModel: ClockViewModel
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Spacer(minLength: 20)

            VStack(spacing: 24) {
                Text(viewModel.state.username)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.15, green: 0.25, blue: 0.4))

                Text(currentDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                clockButton

                durationLabel

                locationBar

                if let err = viewModel.state.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 8) {
                if !viewModel.state.geofenceName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text(viewModel.state.geofenceName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 24) {
                    Button(action: { showHistory = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("History")
                        }
                        .foregroundColor(Color(red: 0.18, green: 0.65, blue: 0.4))
                        .font(.footnote)
                    }

                    Button(action: { viewModel.logout() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                        }
                        .foregroundColor(.secondary)
                        .font(.footnote)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .padding(.top, 8)
        .sheet(isPresented: $showHistory) {
            HistoryView()
                .environmentObject(viewModel)
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AARC Clock in")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.15, green: 0.25, blue: 0.4))
            }
            Spacer()
            Circle()
                .fill(clockedInColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(clockedInColor.opacity(0.3), lineWidth: 4)
                        .frame(width: 18, height: 18)
                )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var clockButton: some View {
        Button(action: {
            Task { await viewModel.toggleClock() }
        }) {
            ZStack {
                Circle()
                    .fill(clockedInGradient)
                    .frame(width: 200, height: 200)
                    .shadow(color: clockedInColor.opacity(0.4), radius: 18, y: 8)

                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 170, height: 170)

                VStack(spacing: 6) {
                    Image(systemName: viewModel.state.clockedIn ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                    Text(viewModel.state.clockedIn ? "Clock Out" : "Clock In")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
            }
            .scaleEffect(viewModel.state.isSubmitting ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: viewModel.state.isSubmitting)
            .animation(.easeInOut(duration: 0.3), value: viewModel.state.clockedIn)
        }
        .disabled(viewModel.state.isSubmitting)
    }

    private var durationLabel: some View {
        Text(formattedDuration)
            .font(.system(size: 32, weight: .medium, design: .monospaced))
            .foregroundColor(Color(red: 0.15, green: 0.25, blue: 0.4))
            .contentTransition(.numericText())
    }

    private var locationBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(locationDotColor)
                .frame(width: 8, height: 8)

            Text(viewModel.state.locationStatus.label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        )
        .padding(.horizontal, 8)
    }

    private var clockedInColor: Color {
        viewModel.state.clockedIn ? Color(red: 0.85, green: 0.27, blue: 0.27) : Color(red: 0.18, green: 0.65, blue: 0.4)
    }

    private var clockedInGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                clockedInColor,
                clockedInColor.opacity(0.85)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var locationDotColor: Color {
        switch viewModel.state.locationStatus {
        case .inside: return .green
        case .outside: return .red
        case .unavailable: return .gray
        case .denied: return .red
        case .unknown: return .orange
        }
    }

    private var formattedDuration: String {
        let s = viewModel.state.durationSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return "\(h)h \(m)m \(sec)s"
    }

    private var currentDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: Date())
    }
}