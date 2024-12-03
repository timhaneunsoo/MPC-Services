//
//  ContentView.swift
//  MessiahPresbyterianServices
//
//  Created by Tim Han on 12/2/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @State private var isLoggedIn = Auth.auth().currentUser != nil
    @State private var isAdmin = false

    var body: some View {
        Group {
            if isLoggedIn {
                MainTabView(isLoggedIn: $isLoggedIn, isAdmin: $isAdmin)
            } else {
                NavigationView {
                    LoginView(isLoggedIn: $isLoggedIn)
                }
            }
        }
        .onAppear {
            _ = Auth.auth().addStateDidChangeListener { _, user in
                isLoggedIn = user != nil
                checkIfAdmin()
            }
        }
    }

    private func checkIfAdmin() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(userID).getDocument { snapshot, error in
            if let data = snapshot?.data(), let role = data["role"] as? String {
                isAdmin = (role == "admin")
            }
        }
    }
}

struct MainTabView: View {
    @Binding var isLoggedIn: Bool
    @Binding var isAdmin: Bool

    var body: some View {
        TabView {
            // Team Schedule View
            NavigationView {
                ScheduleView()
                    .navigationTitle("Schedule")
            }
            .tabItem {
                Label("Schedule", systemImage: "calendar")
            }

            // Set List View
            NavigationView {
                SetListView()
                    .navigationTitle("Set List")
            }
            .tabItem {
                Label("Set List", systemImage: "music.note.list")
            }

            // Song Sheets View
            NavigationView {
                SongSheetsView()
                    .navigationTitle("Song Sheets")
            }
            .tabItem {
                Label("Song Sheets", systemImage: "doc.text")
            }

            // Team Management View (Admin Only)
            if isAdmin {
                NavigationView {
                    AdminView()
                        .navigationTitle("Admin")
                }
                .tabItem {
                    Label("Admin", systemImage: "person.3")
                }
            }

            // Settings/Logout View
            NavigationView {
                MainView(isLoggedIn: $isLoggedIn)
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

struct MainView: View {
    @Binding var isLoggedIn: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Log Out Button
            Button(action: logOut) {
                HStack {
                    Image(systemName: "arrow.backward.square")
                        .foregroundColor(.white)
                    Text("Log Out")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(8)
            }

            Spacer() // Push the button to the bottom of the view
        }
        .padding()
    }

    private func logOut() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}
