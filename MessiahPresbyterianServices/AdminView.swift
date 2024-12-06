//
//  AdminView.swift
//

import SwiftUI

struct AdminView: View {
    let orgId: String // Organization ID passed from ContentView

    var body: some View {
        List {
            NavigationLink(destination: UsersView(orgId: orgId)) {
                Label("Manage Users", systemImage: "person")
            }
            NavigationLink(destination: ConfigView(orgId: orgId)) {
                Label("Organization Settings", systemImage: "gearshape")
            }
            NavigationLink(destination: ManageSetView(orgId: orgId)) {
                Label("Manage Set", systemImage: "doc.text.fill")
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Admin Panel")
    }
}
