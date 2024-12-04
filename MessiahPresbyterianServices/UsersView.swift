//
//  UsersView.swift
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UsersView: View {
    @State private var users: [User] = []
    @State private var errorMessage = ""
    @State private var isLoading = true
    private let db = Firestore.firestore()

    var body: some View {
        VStack {
            Text("Manage Users")
                .font(.largeTitle)
                .padding()

            if isLoading {
                ProgressView()
                    .padding()
            } else if users.isEmpty {
                Text("No users found.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List {
                    ForEach(users, id: \.id) { user in
                        VStack(alignment: .leading) {
                            // Email (not editable)
                            HStack {
                                Text("Email:")
                                    .fontWeight(.bold)
                                Text(user.email)
                                    .foregroundColor(.gray)
                            }

                            // First Name (editable)
                            HStack {
                                Text("First Name:")
                                    .fontWeight(.bold)
                                TextField("First Name", text: Binding(
                                    get: { user.firstName },
                                    set: { newValue in updateUserField(user: user, field: "first_name", value: newValue) }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            }

                            // Last Name (editable)
                            HStack {
                                Text("Last Name:")
                                    .fontWeight(.bold)
                                TextField("Last Name", text: Binding(
                                    get: { user.lastName },
                                    set: { newValue in updateUserField(user: user, field: "last_name", value: newValue) }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            }

                            // Role (editable)
                            HStack {
                                Text("Role:")
                                    .fontWeight(.bold)
                                Picker("Role", selection: Binding(
                                    get: { user.role },
                                    set: { newValue in updateUserField(user: user, field: "role", value: newValue) }
                                )) {
                                    Text("Admin").tag("admin")
                                    Text("User").tag("user")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .padding()
        .onAppear(perform: fetchUsers)
        .alert(isPresented: .constant(!errorMessage.isEmpty)) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }

    // Fetch Users from Firestore
    private func fetchUsers() {
        isLoading = true
        db.collection("users").getDocuments { snapshot, error in
            isLoading = false
            if let error = error {
                self.errorMessage = "Error fetching users: \(error.localizedDescription)"
                return
            }

            guard let documents = snapshot?.documents else {
                self.errorMessage = "No users found."
                return
            }

            self.users = documents.compactMap { doc -> User? in
                let data = doc.data()
                return User(
                    id: doc.documentID,
                    email: data["email"] as? String ?? "N/A",
                    firstName: data["first_name"] as? String ?? "",
                    lastName: data["last_name"] as? String ?? "",
                    role: data["role"] as? String ?? "user"
                )
            }
        }
    }

    // Update User Field in Firestore
    private func updateUserField(user: User, field: String, value: String) {
        guard let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        users[index].setValue(for: field, value: value)

        db.collection("users").document(user.id).updateData([field: value]) { error in
            if let error = error {
                self.errorMessage = "Error updating \(field): \(error.localizedDescription)"
            }
        }
    }
}

// User Model
struct User: Identifiable {
    let id: String
    var email: String
    var firstName: String
    var lastName: String
    var role: String

    mutating func setValue(for field: String, value: String) {
        switch field {
        case "first_name":
            self.firstName = value
        case "last_name":
            self.lastName = value
        case "role":
            self.role = value
        default:
            break
        }
    }
}
