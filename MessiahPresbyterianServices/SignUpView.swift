//
//  SignUpView.swift
//  MessiahPresbyterianServices
//
//  Created by Tim Han on 12/2/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode // To dismiss the view after successful signup
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var role = "user" // Default role is 'user'

    var body: some View {
        VStack(spacing: 20) {
            // Email Input
            TextField("Email", text: $email)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            
            // First Name
            TextField("First Name", text: $firstName)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            
            // Last Name
            TextField("Last Name", text: $lastName)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            // Password Input
            SecureField("Password", text: $password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            // Confirm Password Input
            SecureField("Confirm Password", text: $confirmPassword)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            // Role Selection (Optional: For admin to assign roles while creating accounts)
            Picker("Role", selection: $role) {
                Text("User").tag("user")
                Text("Admin").tag("admin")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            // Sign-Up Button
            Button(action: {
                signUp()
            }) {
                Text("Sign Up")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(8)
            }

            // Error Message Display
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .navigationTitle("Create an Account")
    }

    private func signUp() {
        // Check password confirmation
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        // Create user with Firebase Auth
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = handleFirebaseError(error)
            } else if let userId = result?.user.uid {
                saveUserToFirestore(userId: userId)
            }
        }
    }

    private func saveUserToFirestore(userId: String) {
        // Save user data to Firestore
        let userData: [String: Any] = [
            "email": email,
            "first_name": firstName,
            "last_name": lastName,
            "role": role,
            "blockout_dates": [],
        ]

        Firestore.firestore().collection("users").document(userId).setData(userData) { error in
            if let error = error {
                errorMessage = "Error saving user data: \(error.localizedDescription)"
            } else {
                errorMessage = "Account created successfully! Please log in."
                presentationMode.wrappedValue.dismiss() // Dismiss the SignUpView
            }
        }
    }

    private func handleFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "This email is already in use. Please log in or use another email."
        case AuthErrorCode.weakPassword.rawValue:
            return "Your password is too weak. Please use a stronger password."
        case AuthErrorCode.invalidEmail.rawValue:
            return "Invalid email address. Please check and try again."
        default:
            return "An unknown error occurred. Please try again."
        }
    }
}
