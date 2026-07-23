import SwiftUI

struct RootView: View {
    @EnvironmentObject var viewModel: ClockViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.94, green: 0.96, blue: 0.98),
                    Color(red: 0.88, green: 0.92, blue: 0.96)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            switch viewModel.state.screen {
            case .loading:
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("AARC Clock in")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.2, green: 0.35, blue: 0.55))
                }
            case .login:
                LoginScreen()
            case .clock:
                ClockScreen()
            }
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.state.lastError ?? "")
        }
        .preferredColorScheme(.light)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.lastError != nil },
            set: { if !$0 { viewModel.state.lastError = nil } }
        )
    }
}