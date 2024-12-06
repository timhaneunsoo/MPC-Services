import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ConfigView: View {
    let orgId: String // Organization ID passed from the parent view

    @State private var playlistURL: String = ""
    @State private var folderID: String = ""
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var isAdmin: Bool = false

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Text("Admin Configuration")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)

                // Playlist URL
                VStack(alignment: .leading) {
                    Text("Default YouTube Playlist URL")
                        .font(.headline)
                    TextField("Enter playlist URL", text: $playlistURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.bottom)
                    Button(action: savePlaylistURL) {
                        Text("Save Playlist URL")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }

                // Google Drive Folder ID
                VStack(alignment: .leading) {
                    Text("Google Drive Folder ID")
                        .font(.headline)
                    TextField("Enter folder ID", text: $folderID)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.bottom)
                    Button(action: saveFolderID) {
                        Text("Save Folder ID")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }

                // Error Message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()

            if isLoading {
                ProgressView("Loading...")
            }
        }
        .onAppear(perform: fetchConfig)
    }

    // Fetch Config Data for Selected Organization
    private func fetchConfig() {
        isLoading = true

        db.collection("organizations").document(orgId).collection("config").document("settings").getDocument { snapshot, error in
            defer { isLoading = false }
            if let data = snapshot?.data() {
                playlistURL = data["default_playlist_url"] as? String ?? ""
                folderID = data["google_drive_folder_id"] as? String ?? ""
            } else if let error = error {
                errorMessage = "Error fetching config: \(error.localizedDescription)"
            }
        }

        // Fetch user role to check admin status
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated."
            return
        }

        db.collection("users").document(userId).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                isAdmin = (data["role"] as? String) == "admin"
            } else if let error = error {
                errorMessage = "Error fetching user data: \(error.localizedDescription)"
            }
        }
    }

    // Save Playlist URL for Selected Organization
    private func savePlaylistURL() {
        guard isAdmin else {
            errorMessage = "You do not have admin privileges."
            return
        }
        isLoading = true

        db.collection("organizations").document(orgId).collection("config").document("settings").setData(["default_playlist_url": playlistURL], merge: true) { error in
            isLoading = false
            if let error = error {
                errorMessage = "Error saving playlist URL: \(error.localizedDescription)"
            }
        }
    }

    // Save Folder ID for Selected Organization
    private func saveFolderID() {
        guard isAdmin else {
            errorMessage = "You do not have admin privileges."
            return
        }
        isLoading = true

        db.collection("organizations").document(orgId).collection("config").document("settings").setData(["google_drive_folder_id": folderID], merge: true) { error in
            isLoading = false
            if let error = error {
                errorMessage = "Error saving folder ID: \(error.localizedDescription)"
            }
        }
    }
}
