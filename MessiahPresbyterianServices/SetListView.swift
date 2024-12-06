import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PDFKit

struct SetListView: View {
    @State private var selectedDate = Date() // Selected date for the set
    @State private var youtubePlaylistURL: String = ""
    @State private var songOrder: [String] = []
    @State private var team: [[String: String]] = []
    @State private var errorMessage: String = ""
    @State private var accessToken: String?
    @State private var combinedFileURL: URL?
    @State private var isPreviewVisible: Bool = false
    @State private var isLoading: Bool = false
    @State private var folderID: String = "" // Google Drive Folder ID from Config
    @State private var userOrgIds: [String] = [] // Org IDs the user belongs to
    @State private var userRole: String = "" // User's role

    let orgId: String // Pass the orgId from parent view

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Select Date Section
                    HStack {
                        Text("Select Date")
                            .font(.headline)
                        Spacer()
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                            .onChange(of: selectedDate) { _ in
                                fetchSetData()
                            }
                    }
                    
                    // YouTube Playlist Section
                    if !youtubePlaylistURL.isEmpty {
                        VStack(alignment: .leading) {
                            Text("YouTube Playlist")
                                .font(.headline)
                            WebView(urlString: youtubePlaylistURL)
                                .frame(height: 400)
                                .cornerRadius(8)
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Song Order Section
                    VStack(alignment: .center) { // Center the entire VStack
                        Text("Song Order")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center) // Center the header

                        if songOrder.isEmpty {
                            Text("No songs added for this date.")
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center) // Center the placeholder text
                        } else {
                            VStack(alignment: .center) { // Center the songs and button
                                ForEach(songOrder, id: \.self) { song in
                                    Text(song)
                                        .padding(.vertical, 5)
                                        .frame(maxWidth: isIpad() ? 700 : .infinity)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .multilineTextAlignment(.center) // Center the song text
                                }
                                Button(action: {
                                    if accessToken == nil {
                                        fetchAccessToken { success in
                                            if success {
                                                combineAndViewAllSongs()
                                            } else {
                                                errorMessage = "Failed to fetch access token. Please try again."
                                            }
                                        }
                                    } else {
                                        combineAndViewAllSongs()
                                    }
                                }) {
                                    Text("View Music Sheets")
                                        .padding()
                                        .frame(maxWidth: isIpad() ? 700 : .infinity)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center) // Center the song list
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .fullScreenCover(isPresented: $isPreviewVisible) {
                        if let fileURL = combinedFileURL {
                            PDFViewer(pdfURL: fileURL)
                        } else {
                            VStack {
                                Text("Failed to load file.")
                                    .foregroundColor(.red)
                                Button("Close") {
                                    isPreviewVisible = false
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Team Section
                    VStack(alignment: .center) { // Center the entire VStack
                        Text("Team")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center) // Center the header

                        if team.isEmpty {
                            Text("No team members added for this date.")
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center) // Center the placeholder text
                        } else {
                            VStack(alignment: .center) { // Center the team list
                                ForEach(team, id: \.self) { member in
                                    Text("\(member["name"] ?? "Unknown") - \(member["role"] ?? "Unknown Role")")
                                        .padding(.vertical, 5)
                                        .frame(maxWidth: isIpad() ? 700 : .infinity)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .multilineTextAlignment(.center) // Center each team member text
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center) // Center the entire team list
                        }
                    }
                    .frame(maxWidth: .infinity) // Center the entire section
                    
                    // Error Message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .padding()
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
        .navigationTitle("Set List")
        .onAppear(perform: fetchUserData)
        .sheet(isPresented: $isPreviewVisible) {
            if let fileURL = combinedFileURL {
                PDFViewer(pdfURL: fileURL)
            } else {
                Text("Failed to load file.")
            }
        }
    }

    private func fetchAccessToken(completion: @escaping (Bool) -> Void) {
        isLoading = true
        generateAccessToken { token in
            DispatchQueue.main.async {
                self.isLoading = false
                if let token = token {
                    self.accessToken = token
                    completion(true) // Successfully fetched the token
                } else {
                    self.errorMessage = "Failed to generate access token."
                    completion(false) // Failed to fetch the token
                }
            }
        }
    }

    // Fetch User Data
    private func fetchUserData() {
        guard let userID = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated."
            return
        }

        isLoading = true
        db.collection("users").document(userID).getDocument { snapshot, error in
            defer { isLoading = false }
            if let error = error {
                self.errorMessage = "Error fetching user data: \(error.localizedDescription)"
                return
            }

            guard let data = snapshot?.data() else {
                self.errorMessage = "User data not found."
                return
            }

            self.userOrgIds = data["org_ids"] as? [String] ?? []
            self.userRole = data["role"] as? String ?? ""

            if userOrgIds.contains(orgId) {
                fetchConfigAndSetData()
            } else {
                errorMessage = "Access Denied: You do not belong to this organization."
            }
        }
    }

    // Fetch Configuration and Set Data
    private func fetchConfigAndSetData() {
        isLoading = true

        db.collection("organizations").document(orgId).collection("config").document("settings").getDocument { snapshot, error in
            defer { isLoading = false }
            if let error = error {
                self.errorMessage = "Error fetching config: \(error.localizedDescription)"
                return
            }

            if let data = snapshot?.data() {
                youtubePlaylistURL = data["default_playlist_url"] as? String ?? ""
                folderID = data["google_drive_folder_id"] as? String ?? ""
                fetchSetData()
            } else {
                errorMessage = "Configuration not found."
            }
        }
    }

    // Fetch Set Data for the Selected Date
    private func fetchSetData() {
        let documentID = selectedDate.toFirestoreDateString()
        db.collection("organizations").document(orgId).collection("sets").document(documentID).getDocument { snapshot, error in
            defer { isLoading = false }
            if let data = snapshot?.data() {
                // Check for youtube_playlist_url in the set document
                if let playlistURL = data["youtube_playlist_url"] as? String, !playlistURL.isEmpty {
                    youtubePlaylistURL = playlistURL
                } else {
                    // If not found, use the default playlist URL from the config
                    fetchDefaultPlaylistURL()
                }
                songOrder = data["song_order"] as? [String] ?? []
                team = data["team"] as? [[String: String]] ?? []
            } else {
                // If the set document doesn't exist, use the default playlist URL
                fetchDefaultPlaylistURL()
                songOrder = []
                team = []
            }
        }
    }

    // Fetch Default Playlist URL from Configuration
    private func fetchDefaultPlaylistURL() {
        db.collection("organizations").document(orgId).collection("config").document("settings").getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Error fetching default playlist URL: \(error.localizedDescription)"
                return
            }

            if let data = snapshot?.data() {
                youtubePlaylistURL = data["default_playlist_url"] as? String ?? ""
            } else {
                self.errorMessage = "Default playlist URL not found in configuration."
            }
        }
    }

    // Combine and View All Songs
    private func combineAndViewAllSongs() {
        guard !folderID.isEmpty else {
            errorMessage = "Google Drive folder ID is missing."
            return
        }

        isLoading = true
        errorMessage = ""

        Task {
            do {
                let combinedPDF = PDFDocument()

                for song in songOrder {
                    // Fetch file data for the song
                    if let fileData = try await fetchFileData(for: song),
                       let songPDF = PDFDocument(data: fileData) {
                        // Iterate through all pages of the song PDF
                        for pageIndex in 0..<songPDF.pageCount {
                            if let page = songPDF.page(at: pageIndex) {
                                combinedPDF.insert(page, at: combinedPDF.pageCount)
                            }
                        }
                    } else {
                        throw NSError(domain: "CombineSongsError", code: 404, userInfo: [
                            NSLocalizedDescriptionKey: "Failed to fetch file for song: \(song)"
                        ])
                    }
                }

                // Save combined PDF to a temporary file
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CombinedSongs.pdf")
                if combinedPDF.write(to: tempURL) {
                    combinedFileURL = tempURL
                    isPreviewVisible = true
                } else {
                    throw NSError(domain: "CombineSongsError", code: 500, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to save combined PDF file."
                    ])
                }
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    // Fetch File Data Safely
    private func fetchFileData(for song: String) async throws -> Data? {
        guard let accessToken = accessToken else {
            throw NSError(domain: "FetchFileError", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "Access token is missing."
            ])
        }

        var allFiles: [GDriveFile] = []
        var nextPageToken: String? = nil

        repeat {
            do {
                var urlString = "https://www.googleapis.com/drive/v3/files?q='\(folderID)' in parents&fields=nextPageToken,files(id,name,mimeType)"
                if let nextPageToken = nextPageToken {
                    urlString += "&pageToken=\(nextPageToken)"
                }

                guard let url = URL(string: urlString) else {
                    throw NSError(domain: "FetchFileError", code: 400, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid URL for Google Drive API."
                    ])
                }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

                let (data, _) = try await URLSession.shared.data(for: request)
                let result = try JSONDecoder().decode(GDriveFileListWithToken.self, from: data)
                allFiles.append(contentsOf: result.files)
                nextPageToken = result.nextPageToken
            } catch {
                throw NSError(domain: "FetchFileError", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "Error fetching file data: \(error.localizedDescription)"
                ])
            }
        } while nextPageToken != nil

        // Find the matching file by name
        if let file = allFiles.first(where: { $0.name.lowercased().contains(song.lowercased()) }) {
            let urlString = "https://www.googleapis.com/drive/v3/files/\(file.id)/export?mimeType=application/pdf"
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "FetchFileError", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid URL for exporting Google Drive file."
                ])
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                return data
            } catch {
                throw NSError(domain: "FetchFileError", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "Error fetching file data: \(error.localizedDescription)"
                ])
            }
        } else {
            throw NSError(domain: "FetchFileError", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "File not found for song: \(song)"
            ])
        }
    }
    
    // Helper function to check if the device is an iPad
    private func isIpad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}
