//
//  ManageSetView.swift
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ManageSetView: View {
    let orgId: String // Organization ID for managing sets
    @State private var selectedDate = Date() // Selected date for the set
    @State private var youtubePlaylistURL: String = ""
    @State private var songOrder: [String] = [] // List of songs in the set
    @State private var team: [[String: String]] = [] // Team for the set
    @State private var users: [[String: String]] = [] // Available users for team
    @State private var selectedUserID = ""
    @State private var selectedRole = ""
    @State private var isSongPickerVisible = false // Controls song picker visibility
    @State private var accessToken: String?
    @State private var folderID: String = "" // Google Drive folder ID
    @State private var errorMessage = ""
    @State private var isLoading = false // Loading state

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Set Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Manage Set")
                            .font(.largeTitle)
                            .bold()
                            .padding(.top)

                        // Date Picker
                        HStack {
                            Text("Select Date")
                                .font(.headline)
                            Spacer()
                        }
                        DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                            .onChange(of: selectedDate) { _ in
                                fetchSetDetails()
                            }
                            .frame(maxWidth: isIpad() ? 700 : .infinity)

                        // YouTube Playlist
                        HStack {
                            Text("YouTube Playlist URL")
                                .font(.headline)
                            Spacer()
                        }
                        TextField("YouTube Playlist URL", text: $youtubePlaylistURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .frame(maxWidth: isIpad() ? 700 : .infinity)
                        
                        Button(action: savePlaylistURL) {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: isIpad() ? 700 : .infinity, alignment: .leading)

                    // Song List Section
                    VStack(alignment: .leading) {
                        Text("Song Order")
                            .font(.headline)

                        if songOrder.isEmpty {
                            Text("No songs added for this set.")
                                .foregroundColor(.gray)
                        } else {
                            List {
                                ForEach(songOrder, id: \.self) { song in
                                    HStack {
                                        Text(song)
                                            .frame(maxWidth: isIpad() ? 700 : .infinity, alignment: .leading)
                                        Button(action: {
                                            removeSong(song)
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                    }
                                }
                                .onMove(perform: moveSong) // Enable drag-and-drop reordering
                            }
                            .listStyle(InsetGroupedListStyle())
                            .environment(\.editMode, .constant(.active)) // Always enable reordering mode
                            .frame(height: 300)
                        }

                        Button(action: {
                            GoogleDriveHelper.fetchAccessToken { result in
                                switch result {
                                case .success(let token):
                                    // Access token successfully retrieved
                                    accessToken = token
                                    isSongPickerVisible = true
                                case .failure(let error):
                                    // Handle the error
                                    errorMessage = "Failed to fetch access token: \(error.localizedDescription)"
                                }
                            }
                        }) {
                            Text("Add Song from Song Sheets")
                                .frame(maxWidth: isIpad() ? 700 : .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: isIpad() ? 700 : .infinity, alignment: .leading)

                    // Team Management Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Team")
                            .font(.headline)

                        // Table Header
                        HStack {
                            Text("Name").bold().frame(width: 150, alignment: .leading)
                            ForEach(["AV", "Vox", "Bass", "Drums", "Keys", "Elec"], id: \.self) { role in
                                Text(role)
                                    .bold()
                                    .frame(width: 70, alignment: .center)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.bottom, 10)

                        // User Rows
                        ForEach(users, id: \.self) { user in
                            HStack {
                                // User Name
                                Text(user["name"] ?? "Unknown")
                                    .frame(width: 150, alignment: .leading)

                                // Role Checkboxes
                                ForEach(["AV", "Vox", "Bass", "Drums", "Keys", "Elec"], id: \.self) { role in
                                    Button(action: {
                                        toggleRole(for: user, role: role)
                                    }) {
                                        Image(systemName: isRoleAssigned(user: user, role: role) ? "checkmark.square" : "square")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(.blue)
                                    }
                                    .frame(width: 70, alignment: .center)
                                }
                            }
                        }

                        Button(action: saveTeamChanges) {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: isIpad() ? 700 : .infinity, alignment: .leading)
                }
                .frame(maxWidth: isIpad() ? 700 : .infinity, alignment: .leading)
                .padding()
            }

            // Loading Indicator
            if isLoading {
                ProgressView("Loading...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 5)
            }
        }
        .onAppear {
            fetchFolderID() // Pre-fetch folder ID
            fetchUsers()
            fetchSetDetails()
        }
        .sheet(isPresented: $isSongPickerVisible) {
            if let accessToken = accessToken {
                SongPickerView(
                    accessToken: accessToken,
                    folderID: folderID,
                    errorMessage: $errorMessage,
                    onSelect: { selectedSong in
                        addSong(from: selectedSong)
                        isSongPickerVisible = false
                    }
                )
            } else {
                Text("Failed to load songs.")
            }
        }
        .alert(isPresented: .constant(!errorMessage.isEmpty)) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func isRoleAssigned(user: [String: String], role: String) -> Bool {
        return team.contains { $0["id"] == user["id"] && $0["role"] == role }
    }

    private func toggleRole(for user: [String: String], role: String) {
        if isRoleAssigned(user: user, role: role) {
            team.removeAll { $0["id"] == user["id"] && $0["role"] == role }
        } else {
            team.append(["id": user["id"] ?? "", "name": user["name"] ?? "", "role": role])
        }
    }

    private func saveTeamChanges() {
        updateSetData() // Call the existing function to save changes
    }
    
    // Pre-fetch Google Drive Folder ID during `onAppear`
    private func fetchFolderID() {
        isLoading = true
        db.collection("organizations").document(orgId).collection("config").document("settings").getDocument { snapshot, error in
            defer { isLoading = false }
            if let error = error {
                errorMessage = "Error fetching folder ID: \(error.localizedDescription)"
                return
            }
            if let data = snapshot?.data() {
                folderID = data["google_drive_folder_id"] as? String ?? ""
            } else {
                errorMessage = "Folder ID not found in configuration."
            }
        }
    }

    private func fetchSetDetails() {
        let documentID = selectedDate.toFirestoreDateString()
        db.collection("organizations").document(orgId).collection("sets").document(documentID).getDocument { snapshot, error in
            if let error = error {
                errorMessage = "Error fetching set details: \(error.localizedDescription)"
                return
            }

            if let data = snapshot?.data() {
                youtubePlaylistURL = data["youtube_playlist_url"] as? String ?? ""
                songOrder = data["song_order"] as? [String] ?? []
                team = data["team"] as? [[String: String]] ?? []
            } else {
                createSet(documentID: documentID)
            }
        }
    }

    private func addSong(from file: GDriveFile) {
        guard !file.name.isEmpty else { return }
        songOrder.append(file.name)
        updateSetData()
    }

    private func removeSong(_ song: String) {
        songOrder.removeAll { $0 == song }
        updateSetData()
    }

    private func moveSong(from source: IndexSet, to destination: Int) {
        songOrder.move(fromOffsets: source, toOffset: destination)
        updateSetData()
    }

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
            updateSetData()
        }
    }

    private func removeTeamMember(member: [String: String]) {
        team.removeAll { $0 == member }
        updateSetData()
    }

    private func savePlaylistURL() {
        let documentID = selectedDate.toFirestoreDateString()
        isLoading = true

        db.collection("organizations").document(orgId).collection("sets").document(documentID).updateData([
            "youtube_playlist_url": youtubePlaylistURL
        ]) { error in
            isLoading = false
            if let error = error {
                errorMessage = "Error saving playlist URL: \(error.localizedDescription)"
            }
        }
    }

    private func updateSetData() {
        let documentID = selectedDate.toFirestoreDateString()
        db.collection("organizations").document(orgId).collection("sets").document(documentID).setData([
            "youtube_playlist_url": youtubePlaylistURL,
            "song_order": songOrder,
            "team": team
        ], merge: true) { error in
            if let error = error {
                errorMessage = "Error updating set: \(error.localizedDescription)"
            }
        }
    }
    
    // Fetch Users in Organization
        private func fetchUsers() {
            db.collection("users").whereField("org_ids", arrayContains: orgId).getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = "Error fetching users: \(error.localizedDescription)"
                }

                if let snapshot = snapshot {
                    self.users = snapshot.documents.map { document in
                        let data = document.data()
                        return [
                            "id": document.documentID,
                            "name": "\(data["first_name"] as? String ?? "") \(data["last_name"] as? String ?? "")"
                        ]
                    }
                }
            }
        }

    private func createSet(documentID: String) {
        // First fetch the default playlist URL
        db.collection("organizations")
            .document(orgId)
            .collection("config")
            .document("settings")
            .getDocument { snapshot, error in
                if let error = error {
                    errorMessage = "Error fetching config: \(error.localizedDescription)"
                    return
                }
                
                // Get the default URL from config
                let defaultURL = snapshot?.data()?["default_playlist_url"] as? String ?? ""
                
                // Create set with the default URL
                self.db.collection("organizations")
                    .document(self.orgId)
                    .collection("sets")
                    .document(documentID)
                    .setData([
                        "date": self.selectedDate.toFirestoreDateString(),
                        "youtube_playlist_url": defaultURL,  // Use default URL here
                        "song_order": [],
                        "team": []
                    ]) { error in
                        if let error = error {
                            self.errorMessage = "Error creating new set: \(error.localizedDescription)"
                        }
                    }
            }
    }

    
    private func isIpad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}

struct SongPickerView: View {
    let accessToken: String
    let folderID: String
    @Binding var errorMessage: String
    var onSelect: (GDriveFile) -> Void

    @State private var fetchedFiles: [GDriveFile] = []
    @State private var nextPageToken: String? = nil // Track pagination
    @State private var isLoading = false // Loading state

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    if fetchedFiles.isEmpty && !isLoading {
                        Text("No songs available.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List {
                            ForEach(fetchedFiles, id: \.id) { song in
                                Button(action: {
                                    onSelect(song)
                                }) {
                                    Text(song.name)
                                }
                            }

                            // Load more button for pagination
                            if nextPageToken != nil && !isLoading {
                                Button("Load More") {
                                    fetchFiles()
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                            }
                        }
                    }
                }

                // Loading Indicator
                if isLoading {
                    VStack {
                        ProgressView("Loading...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                }
            }
            .navigationTitle("Select a Song")
            .onAppear(perform: fetchFiles)
            .alert(isPresented: .constant(!errorMessage.isEmpty)) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func fetchFiles() {
        isLoading = true // Start loading
        var urlString = "https://www.googleapis.com/drive/v3/files?q='\(folderID)'+in+parents&fields=nextPageToken,files(id,name,mimeType)&orderBy=name"
        if let token = nextPageToken {
            urlString += "&pageToken=\(token)"
        }
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            isLoading = false // Stop loading
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error fetching files: \(error.localizedDescription)"
                    print("Fetch files error: \(error.localizedDescription)") // Debug log
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received."
                    print("No data received from API") // Debug log
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(GDriveFileListWithToken.self, from: data)
                DispatchQueue.main.async {
                    fetchedFiles.append(contentsOf: result.files)
                    fetchedFiles = fetchedFiles.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
                    nextPageToken = result.nextPageToken // Update next page token
                    print("Fetched files: \(result.files)") // Debug log
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error parsing file data: \(error.localizedDescription)"
                    print("Parse error: \(error.localizedDescription)") // Debug log
                }
            }
        }.resume()
    }
}
