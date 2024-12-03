//
//  LoginView.swift
//  MessiahPresbyterianServices
//
//  Created by Tim Han on 12/2/24.
//

import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            // Email Input
            TextField("Email", text: $email)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            // Password Input
            SecureField("Password", text: $password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            // Log In Button
            Button(action: {
                login()
            }) {
                Text("Log In")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }

            // Navigate to Sign-Up View
            NavigationLink("Create an Account", destination: SignUpView())

            // Forgot Password Button
            Button(action: {
                resetPassword()
            }) {
                Text("Forgot Password?")
                    .font(.footnote)
                    .foregroundColor(.blue)
            }

            // Error Message Display
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .navigationTitle("Log In") // Add a title for better navigation context
    }

    private func login() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = handleFirebaseError(error)
            } else {
                isLoggedIn = true
            }
        }
    }

    private func resetPassword() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email to reset your password."
            return
        }

        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                errorMessage = handleFirebaseError(error)
            } else {
                errorMessage = "Password reset email sent. Check your inbox!"
            }
        }
    }

    private func handleFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.invalidEmail.rawValue:
            return "Invalid email address. Please check and try again."
        case AuthErrorCode.wrongPassword.rawValue:
            return "Incorrect password. Please try again."
        case AuthErrorCode.userNotFound.rawValue:
            return "No user found with this email."
        default:
            return "An unknown error occurred. Please try again."
        }
    }
}
