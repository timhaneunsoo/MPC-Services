//
//  SetListView.swift
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SetListView: View {
    @State private var youtubePlaylistURL = "https://youtube.com/playlist?list=PLavTLgD-iMwMxHPbQTVKkFbpB8x0F0kyv&si=7wIwjVbcqP6taY9y"
    @State private var songOrder: [String] = []
    @State private var team: [[String: String]] = [] // Array of maps [{ "name": "John", "role": "Guitarist" }]
    @State private var errorMessage = ""

    private let db = Firestore.firestore()
    private let currentWeekID = "currentWeekID" // Replace with actual logic to fetch the current week ID

    var body: some View {
        ScrollView { // Make the entire view scrollable
            VStack(alignment: .leading, spacing: 20) { // Add spacing for better layout
                // YouTube Playlist
                if !youtubePlaylistURL.isEmpty {
                    VStack(alignment: .leading) {
                        Text("YouTube Playlist")
                            .font(.headline)
                        WebView(urlString: youtubePlaylistURL)
                            .frame(height: 300) // Adjust height for better visibility
                            .cornerRadius(8)
                    }
                }

                // Song Set Order
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
                        }
                    }
                }

                // Team for the Week
                VStack(alignment: .leading) {
                    Text("Team")
                        .font(.headline)

                    if team.allSatisfy({ $0.isEmpty}) {
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
        .navigationTitle("Set List")
        .onAppear(perform: fetchSetData)
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
                print("Fetched data successfully:")
                print("Song Order: \(songOrder)")
                print("Team: \(team)")
            }
        }
    }
}
