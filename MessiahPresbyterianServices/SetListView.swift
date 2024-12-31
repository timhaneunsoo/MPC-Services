import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SetListView: View {
    @State private var selectedDate = Date()
    @State private var youtubePlaylistURL: String = ""
    @State private var songOrder: [String] = []
    @State private var team: [[String: String]] = []
    @State private var errorMessage: String = ""
    @State private var accessToken: String?
    @State private var transposedText: [String: String] = [:] // Preloaded song contents
    @State private var transpositions: [String: Int] = [:] // Per-song transpositions
    @State private var isLoading: Bool = false
    @State private var folderID: String?
    @State private var isTextViewVisible: Bool = false
    @State private var currentSongIndex: Int = 0 // Track the current song index
    @Environment(\.colorScheme) var colorScheme
    
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
                                    Button(action: {
                                        if let index = songOrder.firstIndex(of: song) {
                                            currentSongIndex = index
                                            isTextViewVisible = true
                                        }
                                    }) {
                                        Text(song)
                                            .padding(.vertical, 5)
                                            .frame(maxWidth: isIpad() ? 700 : .infinity)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
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
                                .frame(maxWidth: isIpad() ? 300 : .infinity, alignment: .center)
                        } else {
                            // Table Header
                            HStack {
                                Text("Team Member").bold().frame(width: 150, alignment: .leading)
                                    .padding(.horizontal)
                                Text("Role").bold().frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.bottom, 10)
                            .frame(maxWidth: isIpad() ? 300 : .infinity)

                            // Team Table Rows
                            ForEach(team, id: \.self) { member in
                                HStack {
                                    Text(member["name"] ?? "Unknown")
                                        .frame(width: 150, alignment: .leading)
                                        .padding(.horizontal)
                                    Text(member["role"] ?? "Unknown Role")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 5)
                                .frame(maxWidth: isIpad() ? 300 : .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
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
        .onAppear(perform: fetchConfigAndAccessToken)
        .fullScreenCover(isPresented: $isTextViewVisible) {
            VStack {
                // Header with close button
                HStack {
                    Text(songOrder[currentSongIndex])
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

                // TabView for swiping through songs
                TabView(selection: $currentSongIndex) {
                    ForEach(songOrder.indices, id: \.self) { index in
                        VStack {
                            ScrollView {
                                let text = transposedText[songOrder[index], default: "Loading..."]
                                let columns = text.components(separatedBy: " || ")

                                HStack(alignment: .top, spacing: 20) {
                                    if columns.count > 0 {
                                        Text(columns[0])
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .font(.body)
                                            .multilineTextAlignment(.leading)
                                            .layoutPriority(1)
                                    }

                                    if columns.count > 1 {
                                        Text(columns[1])
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .font(.body)
                                            .multilineTextAlignment(.leading)
                                            .layoutPriority(1)
                                    }
                                }
                                .padding()
                            }

                            HStack {
                                Button(action: {
                                    let currentTranspose = transpositions[songOrder[index], default: 0]
                                    transpositions[songOrder[index]] = currentTranspose - 1
                                    updateTransposedText(for: songOrder[index])
                                }) {
                                    Image(systemName: "minus.circle")
                                        .font(.largeTitle)
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                                }
                                .padding(.trailing, 20)

                                Text("Transpose: \(transpositions[songOrder[index], default: 0])")
                                    .font(.headline)
                                    .padding(.horizontal, 20)

                                Button(action: {
                                    let currentTranspose = transpositions[songOrder[index], default: 0]
                                    transpositions[songOrder[index]] = currentTranspose + 1
                                    updateTransposedText(for: songOrder[index])
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
                        .tag(index)
                        .onAppear {
                            fetchSongFile(for: songOrder[index])
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
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
                return
            }

            if let data = snapshot?.data() {
                self.folderID = data["google_drive_folder_id"] as? String
                GoogleDriveHelper.fetchAccessToken { result in
                    switch result {
                    case .success(let token):
                        self.accessToken = token
                    case .failure(let error):
                        self.errorMessage = "Failed to fetch access token: \(error.localizedDescription)"
                    }
                }
            } else {
                self.errorMessage = "Config data not found."
            }
        }
    }

    private func fetchSetData() {
        let documentID = selectedDate.toFirestoreDateString()
        db.collection("organizations").document(orgId).collection("sets").document(documentID).getDocument { snapshot, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error fetching set data: \(error.localizedDescription)"
                } else if let data = snapshot?.data() {
                    self.youtubePlaylistURL = data["youtube_playlist_url"] as? String ?? ""
                    self.songOrder = data["song_order"] as? [String] ?? []
                    self.team = data["team"] as? [[String: String]] ?? []
                } else {
                    self.errorMessage = "No set data found for the selected date."
                }
            }
        }
    }

    private func fetchSongFile(for songName: String) {
        guard let folderID = folderID, let accessToken = accessToken else {
            errorMessage = "Folder ID or Access Token is missing."
            return
        }

        isLoading = true
        GoogleDriveHelper.fetchFiles(fromFolderID: folderID, accessToken: accessToken) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let files):
                    if let file = files.first(where: { $0.name.lowercased() == songName.lowercased() }) {
                        self.viewFile(file: file, for: songName)
                    } else {
                        self.errorMessage = "Song not found."
                    }
                case .failure(let error):
                    self.errorMessage = "Error fetching files: \(error.localizedDescription)"
                }
            }
        }
    }

    private func viewFile(file: GDriveFile, for songName: String) {
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
                    let transposeSteps = transpositions[songName, default: 0]
                    self.transposedText[songName] = ChordTransposer.formatAndTransposeSongSheet(text: text, steps: transposeSteps)
                case .failure(let error):
                    self.errorMessage = "Error loading file: \(error.localizedDescription)"
                }
            }
        }
    }

    private func updateTransposedText(for songName: String) {
        guard let folderID = folderID, let accessToken = accessToken else {
            errorMessage = "Folder ID or Access Token is missing."
            return
        }

        GoogleDriveHelper.fetchFiles(fromFolderID: folderID, accessToken: accessToken) { result in
            switch result {
            case .success(let files):
                if let file = files.first(where: { $0.name.lowercased() == songName.lowercased() }) {
                    GoogleDriveHelper.fetchFileAsText(from: file, accessToken: accessToken) { textResult in
                        DispatchQueue.main.async {
                            switch textResult {
                            case .success(let text):
                                let transposeSteps = transpositions[songName, default: 0]
                                self.transposedText[songName] = ChordTransposer.formatAndTransposeSongSheet(text: text, steps: transposeSteps)
                            case .failure(let error):
                                self.errorMessage = "Error updating text: \(error.localizedDescription)"
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Song not found."
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "Error fetching files: \(error.localizedDescription)"
                }
            }
        }
    }

    private func isIpad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}
