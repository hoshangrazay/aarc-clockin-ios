import SwiftUI

struct LoginScreen: View {
    @EnvironmentObject var viewModel: ClockViewModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case username, password
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 0.6))

                Text("AARC Clock in")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.15, green: 0.25, blue: 0.4))

                Text("Volunteer Clock In/Out")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                TextField("Username", text: $viewModel.loginUsername)
                    .focused($focusedField, equals: .username)
                    .textContentType(.username)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

                SecureField("Password", text: $viewModel.loginPassword)
                    .focused($focusedField, equals: .password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .onSubmit {
                        focusedField = nil
                        Task { await viewModel.login() }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            }
            .padding(.horizontal, 32)

            if let err = viewModel.loginError {
                Text(err)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: {
                focusedField = nil
                Task { await viewModel.login() }
            }) {
                HStack {
                    if viewModel.state.isSubmitting {
                        ProgressView().tint(.white)
                    }
                    Text(viewModel.state.isSubmitting ? "Signing in..." : "Sign In")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.2, green: 0.4, blue: 0.6))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.state.isSubmitting)
            .padding(.horizontal, 32)

            Spacer()
            Spacer()

            VStack(spacing: 4) {
                Text("AARC - Asylum and Refugee Care")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("aarcvisitor.com")
                    .font(.caption2)
                    .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.7))
            }
        }
        .onAppear { focusedField = .username }
    }
}