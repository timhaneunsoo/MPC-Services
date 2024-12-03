//
//  TeamView.swift
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct TeamView: View {
    @State private var team: [[String: String]] = [] // Array of team members (user ID, name, role)
    @State private var users: [[String: String]] = [] // All available users to select from
    @State private var selectedUserID = ""
    @State private var selectedRole = ""
    @State private var errorMessage = ""
    @State private var isAdmin = false

    private let db = Firestore.firestore()
    private let currentWeekID = "currentWeekID" // DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none) // e.g., "12/3/24"

    var body: some View {
        VStack {
            // Team List
            Text("Team for This Week")
                .font(.headline)
                .padding(.top)

            List {
                ForEach(team, id: \.self) { member in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(member["name"] ?? "Unknown")
                                .font(.headline)
                            Text(member["role"] ?? "No Role Assigned")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if isAdmin {
                            Picker("Role", selection: Binding(
                                get: { member["role"] ?? "" },
                                set: { newRole in
                                    if let userID = member["id"] {
                                        updateTeamMemberRole(userID: userID, newRole: newRole)
                                    }
                                }
                            )) {
                                Text("Elec").tag("elec")
                                Text("Drum").tag("drum")
                                Text("Vocal").tag("vocal")
                                Text("Keys").tag("keys")
                                Text("AV").tag("av")
                                Text("Bass").tag("bass")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
                .onDelete(perform: isAdmin ? deleteTeamMember : nil)
            }

            // Add New Member
            if isAdmin {
                VStack {
                    Text("Add Team Member")
                        .font(.headline)
                        .padding(.top)

                    Picker("Select User", selection: $selectedUserID) {
                        Text("Select a User").tag("")
                        ForEach(users, id: \.self) { user in
                            Text(user["name"] ?? "Unknown").tag(user["id"] ?? "")
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    Picker("Select Role", selection: $selectedRole) {
                        Text("Select a Role").tag("")
                        Text("Elec").tag("elec")
                        Text("Drum").tag("drum")
                        Text("Vocal").tag("vocal")
                        Text("Keys").tag("keys")
                        Text("AV").tag("av")
                        Text("Bass").tag("bass")
                    }
                    .pickerStyle(MenuPickerStyle())

                    Button(action: {
                        addTeamMember()
                    }) {
                        Text("Add Member")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.top)
                }
                .padding()
            }

            // Error Message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .navigationTitle("Team Management")
        .onAppear(perform: fetchData)
    }

    // Fetch Data from Firestore
    private func fetchData() {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        // Check if the user is an admin
        db.collection("users").document(userID).getDocument { snapshot, error in
            if let data = snapshot?.data(), let role = data["role"] as? String {
                isAdmin = role == "admin"
            }
        }

        // Fetch team data for the current week
        db.collection("weekly_set").document(currentWeekID).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                team = data["team"] as? [[String: String]] ?? []
            }
        }

        // Fetch all users to display in the Picker
        db.collection("users").getDocuments { snapshot, error in
            if let snapshot = snapshot {
                users = snapshot.documents.compactMap { document in
                    let data = document.data()
                    return [
                        "id": document.documentID,
                        "name": "\(data["first_name"] ?? "")"
                    ]
                }
            }
        }
    }

    // Add a Team Member
    private func addTeamMember() {
        guard !selectedUserID.isEmpty, !selectedRole.isEmpty else {
            errorMessage = "Please select a user and a role."
            return
        }

        if let user = users.first(where: { $0["id"] == selectedUserID }) {
            let newMember = [
                "id": selectedUserID,
                "name": user["name"] ?? "Unknown",
                "role": selectedRole
            ]
            team.append(newMember)
            updateFirestoreField("team", with: team)
            selectedUserID = ""
            selectedRole = ""
        }
    }

    // Update a Team Member's Role
    private func updateTeamMemberRole(userID: String, newRole: String) {
        guard let index = team.firstIndex(where: { $0["id"] == userID }) else { return }
        team[index]["role"] = newRole
        updateFirestoreField("team", with: team)
    }

    // Delete a Team Member
    private func deleteTeamMember(at offsets: IndexSet) {
        team.remove(atOffsets: offsets)
        updateFirestoreField("team", with: team)
    }

    // Update Firestore Field
    private func updateFirestoreField(_ field: String, with value: Any) {
        db.collection("weekly_set").document(currentWeekID).setData([field: value], merge: true) { error in
            if let error = error {
                errorMessage = "Error updating \(field): \(error.localizedDescription)"
            }
        }
    }
}
