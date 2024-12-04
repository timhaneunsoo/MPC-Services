import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PDFKit

struct SetListView: View {
    @State private var youtubePlaylistURL = ""
    @State private var songOrder: [String] = []
    @State private var team: [[String: String]] = []
    @State private var errorMessage = ""
    @State private var accessToken: String?
    @State private var isPreviewVisible: Bool = false
    @State private var combinedFileURL: URL? // URL for the combined PDF file
    @State private var isLoading: Bool = false // Loading state

    private let db = Firestore.firestore()
    private let currentWeekID = "currentWeekID" // Replace with actual logic to fetch the current week ID
    private let folderID = "1wOvjYjrYFtKUjArslyV3kcBPymlKddPB" // Your folder ID in Google Drive

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // YouTube Playlist Section
                    if !youtubePlaylistURL.isEmpty {
                        VStack(alignment: .leading) {
                            Text("YouTube Playlist")
                                .font(.headline)
                            WebView(urlString: youtubePlaylistURL)
                                .frame(height: 300)
                                .cornerRadius(8)
                        }
                    }

                    // Song Set Order Section
                    VStack(alignment: .leading) {
                        Text("Song Order")
                            .font(.headline)

                        if songOrder.isEmpty {
                            Text("No songs added for this week.")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            VStack(alignment: .leading) {
                                ForEach(songOrder, id: \.self) { song in
                                    Text(song)
                                        .padding(.vertical, 5)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                Button(action: {
                                    combineAndViewAllSongs()
                                }) {
                                    Text("View Music Sheets")
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }

                    // Team Section
                    VStack(alignment: .leading) {
                        Text("Team")
                            .font(.headline)

                        if team.allSatisfy({ $0.isEmpty }) {
                            Text("No team members added yet.")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            VStack(alignment: .leading) {
                                ForEach(team, id: \.self) { member in
                                    Text("\(member["name"] ?? "Unknown") - \(member["role"] ?? "Unknown Role")")
                                        .padding(.vertical, 5)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                            }
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
        .onAppear {
            fetchAccessToken()
            fetchSetData()
        }
        .sheet(isPresented: $isPreviewVisible) {
            if let fileURL = combinedFileURL {
                PDFViewer(pdfURL: fileURL)
            } else {
                Text("Failed to load file.")
            }
        }
    }

    // Fetch Data from Firestore
    private func fetchSetData() {
        db.collection("weekly_set").document(currentWeekID).getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Error fetching set data: \(error.localizedDescription)"
                return
            }

            if let data = snapshot?.data() {
                youtubePlaylistURL = data["youtube_playlist_url"] as? String ?? ""
                songOrder = data["song_order"] as? [String] ?? []
                team = data["team"] as? [[String: String]] ?? []
            }
        }
    }

    // Fetch Access Token for Google Drive
    private func fetchAccessToken() {
        generateAccessToken { token in
            guard let token = token else {
                self.errorMessage = "Failed to generate access token."
                return
            }
            self.accessToken = token
            print("Access token successfully fetched.")
        }
    }

    // Combine All Songs into One PDF and Preview
    private func combineAndViewAllSongs() {
        guard let accessToken = accessToken else {
            self.errorMessage = "Access token is missing."
            print("Error: Access token is missing.")
            return
        }

        isLoading = true // Start loading

        Task {
            var pdfDocument = PDFDocument()

            for song in songOrder {
                if let fileData = await fetchFileData(for: song) {
                    if let pdfPage = PDFDocument(data: fileData)?.page(at: 0) {
                        pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
                    }
                }
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CombinedSongs.pdf")
            if pdfDocument.write(to: tempURL) {
                combinedFileURL = tempURL
                isPreviewVisible = true
            } else {
                errorMessage = "Failed to create combined PDF."
            }

            isLoading = false // Stop loading
        }
    }

    // Fetch File Data for a Song
    private func fetchFileData(for song: String) async -> Data? {
        guard let accessToken = accessToken else { return nil }

        var allFiles: [GDriveFile] = []
        var nextPageToken: String? = nil

        repeat {
            do {
                var urlString = "https://www.googleapis.com/drive/v3/files?q='\(folderID)' in parents&fields=nextPageToken,files(id,name,mimeType)"
                if let nextPageToken = nextPageToken {
                    urlString += "&pageToken=\(nextPageToken)"
                }

                guard let url = URL(string: urlString) else { return nil }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

                let (data, _) = try await URLSession.shared.data(for: request)
                let result = try JSONDecoder().decode(GDriveFileListWithToken.self, from: data)
                allFiles.append(contentsOf: result.files)
                nextPageToken = result.nextPageToken
            } catch {
                print("Error fetching files: \(error.localizedDescription)")
                return nil
            }
        } while nextPageToken != nil

        if let file = allFiles.first(where: { $0.name.lowercased().contains(song.lowercased()) }) {
            let urlString = "https://www.googleapis.com/drive/v3/files/\(file.id)/export?mimeType=application/pdf"
            guard let url = URL(string: urlString) else { return nil }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                return data
            } catch {
                print("Error downloading file for \(song): \(error.localizedDescription)")
                return nil
            }
        } else {
            print("No file found for song: \(song)")
            return nil
        }
    }
}
