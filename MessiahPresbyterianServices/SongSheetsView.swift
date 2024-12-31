import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SongSheetsView: View {
    @State private var files: [GDriveFile] = []
    @State private var errorMessage: String = ""
    @State private var accessToken: String?
    @State private var isPreviewVisible: Bool = false
    @State private var isTextViewVisible: Bool = false
    @State private var selectedFile: GDriveFile?
    @State private var selectedFileText: String = ""
    @State private var transposedText: String = ""
    @State private var transpositions: [String: Int] = [:] // Dictionary to store transpositions per song
    @State private var isLoading = false // Loading state
    @State private var folderID: String? // Dynamically fetched Google Drive folder ID
    @Environment(\.colorScheme) var colorScheme
    
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
        .fullScreenCover(isPresented: $isTextViewVisible) {
            VStack {
                // Header with Close Button and Title
                HStack {
                    Text(selectedFile?.name ?? "Song Sheet")
                        .font(.title)
                        .bold()
                        .padding(.leading, 20)
                    
                    Spacer()
                    
                    Button(action: {
                        isTextViewVisible = false
                    }) {
                        Image(systemName: "xmark.circle")
                            .font(.title)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                    }
                    .padding(.trailing, 20)
                }
                .padding(.top, 20)
                
                // Two-Column Song Sheet Display
                ScrollView {
                    let columns = transposedText.components(separatedBy: " || ")
                    
                    HStack(alignment: .top, spacing: 20) {
                        // First Column (Before [Order])
                        if columns.count > 0 {
                            Text(columns[0])
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .layoutPriority(1) // Ensure the first column gets priority for space
                        }
                        
                        // Second Column (Order Section + After Order)
                        if columns.count > 1 {
                            Text(columns[1])
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .layoutPriority(1) // Ensure the second column is rendered properly
                        }
                    }
                    .padding()
                }
                
                // Transpose Controls
                HStack {
                    Button(action: {
                        guard let file = selectedFile else { return }
                        let currentTranspose = transpositions[file.id] ?? 0
                        transpositions[file.id] = currentTranspose - 1
                        updateTransposedText(for: file)
                    }) {
                        Image(systemName: "minus.circle")
                            .font(.largeTitle)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                    }
                    .padding(.trailing, 20)
                    
                    Text("Transpose: \(transpositions[selectedFile?.id ?? ""] ?? 0)")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    
                    Button(action: {
                        guard let file = selectedFile else { return }
                        let currentTranspose = transpositions[file.id] ?? 0
                        transpositions[file.id] = currentTranspose + 1
                        updateTransposedText(for: file)
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.largeTitle)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                    }
                }
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .ignoresSafeArea()
        }
    }

    // MARK: - Helper Functions

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

    private func fetchFiles() {
        guard let folderID = folderID, let accessToken = accessToken else {
            self.errorMessage = "Missing folder ID or access token."
            self.isLoading = false
            return
        }

        isLoading = true
        GoogleDriveHelper.fetchFiles(fromFolderID: folderID, accessToken: accessToken) { result in
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
        GoogleDriveHelper.fetchFileAsText(from: file, accessToken: accessToken) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let text):
                    self.selectedFile = file
                    self.selectedFileText = text
                    let transposeSteps = transpositions[file.id] ?? 0
                    self.transposedText = ChordTransposer.formatAndTransposeSongSheet(text: text, steps: transposeSteps)
                    self.isTextViewVisible = true
                case .failure(let error):
                    self.errorMessage = "Error loading file: \(error.localizedDescription)"
                }
            }
        }
    }

    private func updateTransposedText(for file: GDriveFile) {
        guard let accessToken = accessToken else {
            errorMessage = "Missing access token."
            return
        }

        GoogleDriveHelper.fetchFileAsText(from: file, accessToken: accessToken) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    let transposeSteps = transpositions[file.id] ?? 0
                    self.transposedText = ChordTransposer.formatAndTransposeSongSheet(text: text, steps: transposeSteps)
                case .failure(let error):
                    self.errorMessage = "Error updating transposed text: \(error.localizedDescription)"
                }
            }
        }
    }
}
