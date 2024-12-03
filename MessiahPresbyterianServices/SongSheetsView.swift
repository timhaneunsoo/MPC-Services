import SwiftUI

struct SongSheetsView: View {
    @State private var files: [GDriveFile] = []
    @State private var errorMessage: String = ""
    @State private var accessToken: String?
    @State private var isWebViewVisible: Bool = false
    @State private var selectedFileURL: URL?

    private let folderID = "1wOvjYjrYFtKUjArslyV3kcBPymlKddPB" // Replace with your Google Drive folder ID.

    var body: some View {
        VStack {
            if files.isEmpty {
                Text("No files found")
                    .font(.headline)
                    .padding()
            } else {
                List(files, id: \.id) { file in
                    HStack {
                        Text(file.name)
                        Spacer()
                        Button("View") {
                            viewFile(file: file)
                        }
                        .padding(.trailing)

                        Button("Download") {
                            downloadFile(file: file)
                        }
                    }
                }
            }
        }
        .navigationTitle("Song Sheets")
        .onAppear {
            generateAccessToken { token in
                guard let token = token else {
                    errorMessage = "Failed to get access token."
                    return
                }
                accessToken = token
                fetchFiles()
            }
        }
        .alert(isPresented: .constant(!errorMessage.isEmpty)) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $isWebViewVisible) {
            if let url = selectedFileURL?.absoluteString {
                WebView(urlString: url)
            } else {
                Text("Failed to load file.")
            }
        }
    }

    private func fetchFiles() {
        guard let accessToken = accessToken else { return }

        let urlString = "https://www.googleapis.com/drive/v3/files?q='\(folderID)'+in+parents&fields=files(id,name,mimeType)"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Error fetching files: \(error.localizedDescription)"
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    errorMessage = "No data received."
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(GDriveFileList.self, from: data)
                DispatchQueue.main.async {
                    files = result.files
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Error parsing file data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    private func viewFile(file: GDriveFile) {
        guard let accessToken = accessToken else { return }

        let urlString = "https://www.googleapis.com/drive/v3/files/\(file.id)?alt=media"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }

        selectedFileURL = url
        isWebViewVisible = true
    }

    private func downloadFile(file: GDriveFile) {
        guard let accessToken = accessToken else { return }

        let urlString = "https://www.googleapis.com/drive/v3/files/\(file.id)?alt=media"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
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
