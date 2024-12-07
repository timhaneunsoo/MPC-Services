import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PDFKit

struct SetListView: View {
    @State private var selectedDate = Date()
    @State private var youtubePlaylistURL: String = ""
    @State private var songOrder: [String] = []
    @State private var team: [[String: String]] = []
    @State private var errorMessage: String = ""
    @State private var accessToken: String?
    @State private var combinedFileURL: URL?
    @State private var isPreviewVisible: Bool = false
    @State private var isLoading: Bool = false
    @State private var folderID: String = ""
    @State private var userOrgIds: [String] = []
    @State private var userRole: String = ""

    let orgId: String

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
                    VStack(alignment: .center) {
                        Text("Song Order")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)

                        if songOrder.isEmpty {
                            Text("No songs added for this date.")
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            VStack(alignment: .center) {
                                ForEach(songOrder, id: \.self) { song in
                                    Text(song)
                                        .padding(.vertical, 5)
                                        .frame(maxWidth: isIpad() ? 700 : .infinity)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .multilineTextAlignment(.center)
                                }
                                Button(action: combineAndViewAllSongs) {
                                    Text("View Music Sheets")
                                        .padding()
                                        .frame(maxWidth: isIpad() ? 700 : .infinity)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
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
                    VStack(alignment: .center) {
                        Text("Team")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)

                        if team.isEmpty {
                            Text("No team members added for this date.")
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            VStack(alignment: .center) {
                                ForEach(team, id: \.self) { member in
                                    Text("\(member["name"] ?? "Unknown") - \(member["role"] ?? "Unknown Role")")
                                        .padding(.vertical, 5)
                                        .frame(maxWidth: isIpad() ? 700 : .infinity)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
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
                print("Fetched folder ID: \(folderID)") // Debug
                fetchSetData()
            } else {
                errorMessage = "Configuration not found."
            }
        }
    }

    private func fetchSetData() {
        let documentID = selectedDate.toFirestoreDateString()
        db.collection("organizations").document(orgId).collection("sets").document(documentID).getDocument { snapshot, error in
            defer { isLoading = false }
            if let data = snapshot?.data() {
                youtubePlaylistURL = data["youtube_playlist_url"] as? String ?? ""
                songOrder = data["song_order"] as? [String] ?? []
                team = data["team"] as? [[String: String]] ?? []
                print("Fetched set data: \(data)") // Add this for debugging
            } else {
                youtubePlaylistURL = ""
                songOrder = []
                team = []
                print("No set data found for \(documentID)") // Add this for debugging
            }
        }
    }

    private func combineAndViewAllSongs() {
        guard !folderID.isEmpty else {
            errorMessage = "Google Drive folder ID is missing."
            return
        }

        isLoading = true
        errorMessage = ""

        // Step 1: Fetch Access Token
        GoogleDriveHelper.fetchAccessToken { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let token):
                    self.accessToken = token
                    
                    // Step 2: Fetch Files from the Folder
                    GoogleDriveHelper.fetchFiles(fromFolderID: self.folderID, accessToken: token) { fetchResult in
                        DispatchQueue.main.async {
                            switch fetchResult {
                            case .success(let fetchedFiles):
                                // Filter fetched files based on `songOrder`
                                let filesToCombine = fetchedFiles.filter { file in
                                    self.songOrder.contains { song in
                                        song.lowercased() == file.name.lowercased()
                                    }
                                }
                                
                                // Step 3: Generate Combined PDF
                                GoogleDriveHelper.generateCombinedPDF(for: filesToCombine, accessToken: token) { pdfResult in
                                    DispatchQueue.main.async {
                                        self.isLoading = false
                                        switch pdfResult {
                                        case .success(let combinedURL):
                                            self.combinedFileURL = combinedURL
                                            self.isPreviewVisible = true
                                        case .failure(let error):
                                            self.errorMessage = "Failed to generate combined PDF: \(error.localizedDescription)"
                                        }
                                    }
                                }
                            case .failure(let error):
                                self.isLoading = false
                                self.errorMessage = "Error fetching files: \(error.localizedDescription)"
                            }
                        }
                    }
                case .failure(let error):
                    self.isLoading = false
                    self.errorMessage = "Failed to fetch access token: \(error.localizedDescription)"
                }
            }
        }
    }

    private func isIpad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}
