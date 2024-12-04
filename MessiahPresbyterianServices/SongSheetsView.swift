import SwiftUI
import QuickLook

struct SongSheetsView: View {
    @State private var files: [GDriveFile] = []
    @State private var errorMessage: String = ""
    @State private var accessToken: String?
    @State private var isPreviewVisible: Bool = false
    @State private var selectedFileURL: URL?
    @State private var isLoading = false // Loading state

    private let folderID = "1wOvjYjrYFtKUjArslyV3kcBPymlKddPB" // Replace with your Google Drive folder ID.

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
                isLoading = true // Start loading
                generateAccessToken { token in
                    guard let token = token else {
                        DispatchQueue.main.async {
                            errorMessage = "Failed to get access token."
                            isLoading = false
                        }
                        return
                    }
                    accessToken = token
                    fetchFiles()
                }
            }
            .alert(isPresented: .constant(!errorMessage.isEmpty)) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $isPreviewVisible) {
                if let fileURL = selectedFileURL {
                    PDFViewer(pdfURL: fileURL) // Updated to use PDFViewer
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

    private func fetchFiles(pageToken: String? = nil) {
        guard let accessToken = accessToken else {
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
                    files.append(contentsOf: result.files)
                    files = files.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
                    isLoading = false // Stop loading
                    if let nextPageToken = result.nextPageToken {
                        fetchFiles(pageToken: nextPageToken) // Fetch next page if available
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
            isLoading = false // Stop loading
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error loading file: \(error.localizedDescription)"
                }
                print("Error: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Response Status Code: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 403 {
                    print("403 Forbidden: Ensure the service account has access to the file or folder.")
                }
            }

            guard let data = data, data.count > 0 else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received or file is empty."
                }
                return
            }

            do {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(file.name).appendingPathExtension("pdf")
                try data.write(to: tempURL)
                DispatchQueue.main.async {
                    self.selectedFileURL = tempURL
                    self.isPreviewVisible = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error saving file for viewing: \(error.localizedDescription)"
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
            isLoading = false // Stop loading
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Error downloading file: \(error.localizedDescription)"
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    errorMessage = "No data received."
                }
                return
            }

            DispatchQueue.main.async {
                saveToDocumentsDirectory(fileName: file.name, data: data)
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
