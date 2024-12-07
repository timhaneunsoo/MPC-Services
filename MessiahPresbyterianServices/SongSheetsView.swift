import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SongSheetsView: View {
    @State private var files: [GDriveFile] = []
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
                    isLoading = true
                    fetchConfigAndAccessToken()
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
        db.collection("organizations").document(orgId).collection("config").document("settings").getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Error fetching config: \(error.localizedDescription)"
                self.isLoading = false
                return
            }

            if let data = snapshot?.data() {
                self.folderID = data["google_drive_folder_id"] as? String
                GoogleDriveHelper.fetchAccessToken { result in
                    switch result {
                    case .success(let token):
                        self.accessToken = token
                        fetchFiles()
                    case .failure(let error):
                        self.errorMessage = "Failed to fetch access token: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            } else {
                self.errorMessage = "Config data not found for the organization."
                self.isLoading = false
            }
        }
    }

    private func fetchFiles(pageToken: String? = nil) {
        guard let folderID = folderID, let accessToken = accessToken else {
            self.errorMessage = "Missing folder ID or access token."
            self.isLoading = false
            return
        }

        isLoading = true
        GoogleDriveHelper.fetchFiles(fromFolderID: folderID, accessToken: accessToken, pageToken: pageToken) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetchedFiles):
                    self.files.append(contentsOf: fetchedFiles)
                    self.files = self.files.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
                    self.isLoading = false
                case .failure(let error):
                    self.errorMessage = "Error fetching files: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func viewFile(file: GDriveFile) {
        guard let accessToken = accessToken else {
            self.errorMessage = "Missing access token."
            return
        }

        isLoading = true
        GoogleDriveHelper.downloadFile(from: file, accessToken: accessToken) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let data):
                    do {
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(file.name).appendingPathExtension("pdf")
                        try data.write(to: tempURL)
                        self.selectedFileURL = tempURL
                        self.isPreviewVisible = true
                    } catch {
                        self.errorMessage = "Failed to save file: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    self.errorMessage = "Error loading file: \(error.localizedDescription)"
                }
            }
        }
    }

    private func downloadFile(file: GDriveFile) {
        guard let accessToken = accessToken else {
            self.errorMessage = "Missing access token."
            return
        }

        isLoading = true
        GoogleDriveHelper.downloadFile(from: file, accessToken: accessToken) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let data):
                    saveToDocumentsDirectory(fileName: file.name, data: data)
                case .failure(let error):
                    self.errorMessage = "Error downloading file: \(error.localizedDescription)"
                }
            }
        }
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
