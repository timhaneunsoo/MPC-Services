//
//  AdminView.swift
//

import SwiftUI

struct AdminView: View {
    var body: some View {
        List {
            NavigationLink(destination: TeamView()) {
                Label("Manage Team", systemImage: "person.3.fill")
            }
            NavigationLink(destination: SongView()) {
                Label("Manage Songs", systemImage: "music.note.list")
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Admin Panel")
    }
}
