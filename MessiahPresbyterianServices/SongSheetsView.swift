import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SongSheetsView: View {
    @State private var files: [GDriveFile] = []
    @State private var fetchedFileIDs: Set<String> = [] // Track already fetched file IDs
    @State private var errorMessage: String = ""
    @State private var accessToken: String?
    @State private var isPreviewVisible: Bool = false
    @State private var selectedFileURL: URL?
    @State private var isLoading = false // Loading state
    @State private var folderID: String? // Dynamically fetched Google Drive folder ID
    let orgId: String // Organization ID passed into this view

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            VStack {
                if files.isEmpty && !isLoading {
                    Text("No files found")
                        .font(.headline)
                        .padding()
                } else {
                    List(files, id: \.id) { file in
                        HStack {
                            // Tap on file name to view it
                            Button(action: {
                                viewFile(file: file)
                            }) {
                                Text(file.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.primary)
                            }

                            // Download button as an icon
                            Button(action: {
                                downloadFile(file: file)
                            }) {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.blue)
                            }
                            .padding(.leading)
                        }
                    }
                }
            }
            .navigationTitle("Song Sheets")
            .onAppear {
                if files.isEmpty { // Prevent duplicate fetches if already loaded
                    isLoading = true // Start loading
                    fetchedFileIDs = [] // Reset fetched file tracking
                    files = [] // Clear existing files
                    fetchConfigAndAccessToken() // Fetch config and access token before loading files
                }
            }
            .alert(isPresented: .constant(!errorMessage.isEmpty)) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .fullScreenCover(isPresented: $isPreviewVisible) {
                if let fileURL = selectedFileURL {
                    PDFViewer(pdfURL: fileURL)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Text("Failed to load file.")
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
    }

    private func fetchConfigAndAccessToken() {
        // Fetch config from Firestore to get folderID
        let configDocRef = db.collection("organizations").document(orgId).collection("config").document("settings")
        
        configDocRef.getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Error fetching config: \(error.localizedDescription)"
                self.isLoading = false
                return
            }

            if let data = snapshot?.data() {
                self.folderID = data["google_drive_folder_id"] as? String ?? ""
                generateAccessToken { token in
                    guard let token = token else {
                        DispatchQueue.main.async {
                            errorMessage = "Failed to get access token."
                            isLoading = false
                        }
                        return
                    }
                    accessToken = token
                    fetchFiles() // Start fetching files
                }
            } else {
                self.errorMessage = "Config data not found for the organization."
                self.isLoading = false
            }
        }
    }

    private func fetchFiles(pageToken: String? = nil) {
        guard let accessToken = accessToken, let folderID = folderID else {
            isLoading = false
            return
        }

        var urlString = "https://www.googleapis.com/drive/v3/files?q='\(folderID)'+in+parents&fields=nextPageToken,files(id,name,mimeType)"
        if let pageToken = pageToken {
            urlString += "&pageToken=\(pageToken)"
        }
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                errorMessage = "Invalid URL"
                isLoading = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Error fetching files: \(error.localizedDescription)"
                    isLoading = false
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    errorMessage = "No data received."
                    isLoading = false
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(GDriveFileListWithToken.self, from: data)
                DispatchQueue.main.async {
                    // Filter out duplicates before adding
                    let newFiles = result.files.filter { !fetchedFileIDs.contains($0.id) }
                    fetchedFileIDs.formUnion(newFiles.map { $0.id }) // Track fetched IDs
                    files.append(contentsOf: newFiles) // Append unique files
                    files = files.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })

                    if let nextPageToken = result.nextPageToken {
                        fetchFiles(pageToken: nextPageToken) // Fetch next page if available
                    } else {
                        isLoading = false // Stop loading when no more pages
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Error parsing file data: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }.resume()
    }

    private func viewFile(file: GDriveFile) {
        guard let accessToken = accessToken else {
            self.errorMessage = "Missing access token."
            return
        }

        isLoading = true // Start loading
        let urlString = "https://www.googleapis.com/drive/v3/files/\(file.id)/export?mimeType=application/pdf"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error loading file: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received or file is empty."
                    self.isLoading = false
                }
                return
            }

            do {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(file.name).appendingPathExtension("pdf")
                try data.write(to: tempURL)
                DispatchQueue.main.async {
                    self.selectedFileURL = tempURL
                    self.isPreviewVisible = true
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error saving file for viewing: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }.resume()
    }

    private func downloadFile(file: GDriveFile) {
        guard let accessToken = accessToken else { return }

        isLoading = true // Start loading
        let urlString = "https://www.googleapis.com/drive/v3/files/\(file.id)?alt=media"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Error downloading file: \(error.localizedDescription)"
                    isLoading = false
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    errorMessage = "No data received."
                    isLoading = false
                }
                return
            }

            DispatchQueue.main.async {
                saveToDocumentsDirectory(fileName: file.name, data: data)
                isLoading = false
            }
        }.resume()
    }

    private func saveToDocumentsDirectory(fileName: String, data: Data) {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            print("File saved to: \(fileURL.path)")
        } catch {
            errorMessage = "Failed to save file: \(error.localizedDescription)"
        }
    }
}
