//
//  SongView.swift
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SongView: View {
    @State private var songOrder: [String] = []
    @State private var accessToken: String?
    @State private var errorMessage = ""
    @State private var isSongPickerVisible = false
    @State private var isLoading = false // Loading state

    private let db = Firestore.firestore()
    private let currentWeekID = "currentWeekID" // Replace with actual logic to fetch the current week ID
    private let folderID = "1wOvjYjrYFtKUjArslyV3kcBPymlKddPB" // Replace with your Google Drive folder ID.

    var body: some View {
        ZStack {
            VStack {
                Text("This Week's Songs")
                    .font(.largeTitle)
                    .padding()
                    .bold()

                // Song List with Reordering and Deleting
                List {
                    ForEach(songOrder, id: \.self) { song in
                        HStack {
                            Text(song)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(action: {
                                removeSong(song)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .onMove(perform: moveSong) // Enable reordering
                }
                .listStyle(InsetGroupedListStyle())
                .environment(\.editMode, .constant(.active)) // Force edit mode for drag handles

                // Add New Song Button
                Button(action: {
                    fetchAccessToken {
                        isSongPickerVisible = true
                    }
                }) {
                    Text("Add Song from Song Sheets")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()

                // Error Message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()

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
        .onAppear(perform: fetchSongOrder)
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
    }

    // Fetch Song Order from Firestore
    private func fetchSongOrder() {
        isLoading = true // Start loading
        db.collection("weekly_set").document(currentWeekID).getDocument { snapshot, error in
            defer { isLoading = false } // Stop loading after the operation
            if let error = error {
                self.errorMessage = "Error fetching song order: \(error.localizedDescription)"
                return
            }

            if let data = snapshot?.data() {
                songOrder = data["song_order"] as? [String] ?? []
            }
        }
    }

    // Add a New Song
    private func addSong(from file: GDriveFile) {
        guard !file.name.isEmpty else { return }
        isLoading = true // Start loading
        songOrder.append(file.name)
        updateFirestore()
    }

    // Remove a Song
    private func removeSong(_ song: String) {
        if let index = songOrder.firstIndex(of: song) {
            isLoading = true // Start loading
            songOrder.remove(at: index)
            updateFirestore()
        }
    }

    // Move a Song in the List
    private func moveSong(from source: IndexSet, to destination: Int) {
        isLoading = true // Start loading
        songOrder.move(fromOffsets: source, toOffset: destination)
        updateFirestore()
    }

    // Update Firestore
    private func updateFirestore() {
        db.collection("weekly_set").document(currentWeekID).setData(["song_order": songOrder], merge: true) { error in
            isLoading = false // Stop loading after the update
            if let error = error {
                self.errorMessage = "Error updating song order: \(error.localizedDescription)"
            }
        }
    }

    // Fetch Access Token
    private func fetchAccessToken(completion: @escaping () -> Void) {
        isLoading = true // Start loading
        generateAccessToken { token in
            defer { isLoading = false } // Stop loading after the token fetch
            guard let token = token else {
                self.errorMessage = "Failed to generate access token."
                return
            }
            self.accessToken = token
            completion()
        }
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

        URLSession.shared.dataTask(with: request) { data, _, error in
            isLoading = false // Stop loading
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
                let result = try JSONDecoder().decode(GDriveFileListWithToken.self, from: data)
                DispatchQueue.main.async {
                    fetchedFiles.append(contentsOf: result.files)
                    fetchedFiles = fetchedFiles.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
                    nextPageToken = result.nextPageToken // Update next page token
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Error parsing file data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}
