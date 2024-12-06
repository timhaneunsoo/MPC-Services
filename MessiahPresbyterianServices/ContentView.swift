import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @State private var isLoggedIn = Auth.auth().currentUser != nil
    @State private var isAdmin = false
    @State private var orgIds: [String] = [] // List of organizations the user belongs to
    @State private var selectedOrgId: String? = nil // Current organization
    @State private var selectedTab: Tab = .schedule // Default tab
    @State private var showOrgSelection = false // Tracks whether to show org selection

    enum Tab: String, CaseIterable, Identifiable {
        case schedule = "Schedule"
        case setList = "Set List"
        case songSheets = "Song Sheets"
        case admin = "Admin"
        case settings = "Settings"

        var id: String { rawValue }
    }

    var body: some View {
        if isLoggedIn {
            NavigationStack {
                if let selectedOrgId = selectedOrgId {
                    TabView(selection: $selectedTab) {
                        // Schedule Tab
                        ScheduleView(orgId: selectedOrgId)
                            .tabItem {
                                Label("Schedule", systemImage: "calendar")
                            }
                            .tag(Tab.schedule)

                        // Set List Tab
                        SetListView(orgId: selectedOrgId)
                            .tabItem {
                                Label("Set List", systemImage: "music.note.list")
                            }
                            .tag(Tab.setList)

                        // Song Sheets Tab
                        SongSheetsView(orgId: selectedOrgId)
                            .tabItem {
                                Label("Song Sheets", systemImage: "doc.text")
                            }
                            .tag(Tab.songSheets)

                        // Admin Tab (Admin Only)
                        if isAdmin {
                            AdminView(orgId: selectedOrgId)
                                .tabItem {
                                    Label("Admin", systemImage: "person.3")
                                }
                                .tag(Tab.admin)
                        }

                        // Settings Tab
                        MainView(isLoggedIn: $isLoggedIn, selectedOrgId: $selectedOrgId, orgIds: $orgIds)
                            .tabItem {
                                Label("Settings", systemImage: "gear")
                            }
                            .tag(Tab.settings)
                    }
                } else if showOrgSelection {
                    // Organization Selection View
                    SelectOrganizationView(orgIds: $orgIds, selectedOrgId: $selectedOrgId)
                        .onDisappear {
                            if selectedOrgId != nil {
                                // Ensure organization is selected before proceeding
                                showOrgSelection = false
                            }
                        }
                }
            }
            .onAppear {
                if selectedOrgId == nil && !showOrgSelection {
                    // Automatically show organization selection if not set
                    fetchUserOrganizations {
                        showOrgSelection = orgIds.count > 1
                    }
                }
            }
        } else {
            NavigationStack {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
    }

    private func fetchUserOrganizations(completion: (() -> Void)? = nil) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("User ID not found.")
            return
        }

        Firestore.firestore().collection("users").document(userID).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user organizations: \(error.localizedDescription)")
                return
            }

            guard let data = snapshot?.data() else {
                print("No data found for user.")
                return
            }

            DispatchQueue.main.async {
                self.orgIds = data["org_ids"] as? [String] ?? []

                if self.orgIds.isEmpty {
                    print("User has no organizations.")
                    self.selectedOrgId = nil
                } else if self.orgIds.count == 1 {
                    print("Auto-selecting the only organization: \(self.orgIds.first ?? "")")
                    self.selectedOrgId = self.orgIds.first
                } else {
                    print("Multiple organizations found. User needs to select one.")
                    self.selectedOrgId = nil // Allow user to select an organization
                }

                // Update admin status
                self.isAdmin = (data["role"] as? String) == "admin"
                completion?()
            }
        }
    }
}

// Placeholder for tabs without organization
struct PlaceholderView: View {
    let title: String

    var body: some View {
        VStack {
            Text("Select an organization to view \(title).")
                .font(.title2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct MainTabView: View {
    @Binding var isLoggedIn: Bool
    @Binding var isAdmin: Bool
    @Binding var orgIds: [String]
    @Binding var selectedOrgId: String?

    var body: some View {
        TabView {
            // Team Schedule View
            NavigationView {
                if let orgId = selectedOrgId {
                    ScheduleView(orgId: orgId)
                        .navigationTitle("Schedule")
                }
            }
            .tabItem {
                Label("Schedule", systemImage: "calendar")
            }

            // Set List View
            NavigationView {
                if let orgId = selectedOrgId {
                    SetListView(orgId: orgId)
                        .navigationTitle("Set List")
                }
            }
            .tabItem {
                Label("Set List", systemImage: "music.note.list")
            }

            // Song Sheets View
            NavigationView {
                if let orgId = selectedOrgId {
                    SongSheetsView(orgId: orgId)
                        .navigationTitle("Song Sheets")
                }
            }
            .tabItem {
                Label("Song Sheets", systemImage: "doc.text")
            }

            // Team Management View (Admin Only)
            if isAdmin {
                NavigationView {
                    if let orgId = selectedOrgId {
                        AdminView(orgId: orgId)
                            .navigationTitle("Admin")
                    }
                }
                .tabItem {
                    Label("Admin", systemImage: "person.3")
                }
            }

            // Settings/Logout View
            NavigationView {
                MainView(isLoggedIn: $isLoggedIn, selectedOrgId: $selectedOrgId, orgIds: $orgIds)
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
    @Binding var selectedOrgId: String?
    @Binding var orgIds: [String]

    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var role = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var isDirty = false // Tracks if any changes are made

    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 10) {
            // Profile Section
            Text("Profile")
                .font(.largeTitle)
                .bold()

            if isLoading {
                ProgressView("Loading...")
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 15) {
                    // Email
                    HStack {
                        Text("Email:")
                            .fontWeight(.bold)
                        TextField("Email", text: Binding(
                            get: { email },
                            set: {
                                email = $0
                                isDirty = true
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    }

                    // First Name
                    HStack {
                        Text("First Name:")
                            .fontWeight(.bold)
                        TextField("First Name", text: Binding(
                            get: { firstName },
                            set: {
                                firstName = $0
                                isDirty = true
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    // Last Name
                    HStack {
                        Text("Last Name:")
                            .fontWeight(.bold)
                        TextField("Last Name", text: Binding(
                            get: { lastName },
                            set: {
                                lastName = $0
                                isDirty = true
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    // Role (View Only)
                    HStack {
                        Text("Role:")
                            .fontWeight(.bold)
                        Text(role)
                            .foregroundColor(.gray)
                    }

                    // Organization IDs (View Only)
                    VStack(alignment: .leading) {
                        Text("Organizations:")
                            .fontWeight(.bold)
                        ForEach(orgIds, id: \.self) { orgId in
                            Text("- \(orgId)")
                                .foregroundColor(.gray)
                        }
                    }

                    // Organization Selector
                    if orgIds.count > 1 {
                        HStack {
                            Text("Current Organization")
                                .font(.headline)

                            Picker("Select Organization", selection: $selectedOrgId) {
                                ForEach(orgIds, id: \.self) { orgId in
                                    Text(orgId).tag(orgId as String?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: selectedOrgId) { newOrgId in
                                if let newOrgId = newOrgId {
                                    handleOrgSwitch(to: newOrgId)
                                }
                            }
                        }
                    }
                }
                .padding()

                // Save Button (Visible only when `isDirty` is true)
                if isDirty {
                    Button(action: updateProfile) {
                        Text("Save Changes")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                }
            }

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
        }
        .padding()
        .onAppear(perform: fetchUserProfile)
        .alert(isPresented: .constant(!errorMessage.isEmpty)) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }

    // Fetch user profile information
    private func fetchUserProfile() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        db.collection("users").document(userID).getDocument { snapshot, error in
            isLoading = false
            if let error = error {
                errorMessage = "Error fetching profile: \(error.localizedDescription)"
                return
            }

            if let data = snapshot?.data() {
                email = data["email"] as? String ?? ""
                firstName = data["first_name"] as? String ?? ""
                lastName = data["last_name"] as? String ?? ""
                role = data["role"] as? String ?? "User"
                orgIds = data["org_ids"] as? [String] ?? []
                isDirty = false // Reset dirty flag after loading
            } else {
                errorMessage = "Profile data not found."
            }
        }
    }

    // Update user profile
    private func updateProfile() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        let userData: [String: Any] = [
            "email": email,
            "first_name": firstName,
            "last_name": lastName
        ]

        db.collection("users").document(userID).updateData(userData) { error in
            isLoading = false
            if let error = error {
                errorMessage = "Error saving profile: \(error.localizedDescription)"
            } else {
                isDirty = false // Reset dirty flag after successful save
            }
        }
    }

    // Handle organization switch
    private func handleOrgSwitch(to newOrgId: String) {
        print("Switched to organization: \(newOrgId)")
    }

    // Log out the user
    private func logOut() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
            selectedOrgId = nil // Clear the selected organization
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

struct SelectOrganizationView: View {
    @Binding var orgIds: [String]
    @Binding var selectedOrgId: String?

    var body: some View {
        VStack(spacing: 20) {
            // Welcome Text
            Text("Welcome to MPC Services")
                .font(.largeTitle)
                .bold()
                .padding(.bottom, 100)
            
            Text("Select Organization")
                .font(.title)
                .bold()
                .padding(.bottom)

            if orgIds.isEmpty {
                Text("No organizations found.")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: isIpad() ? 400 : .infinity) // Limit width for iPad
            } else {
                VStack(spacing: 10) {
                    ForEach(orgIds, id: \.self) { orgId in
                        Button(action: {
                            selectedOrgId = orgId
                            print("Organization selected: \(orgId)")
                        }) {
                            Text(orgId)
                                .frame(maxWidth: isIpad() ? 400 : .infinity) // Limit button width for iPad
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: isIpad() ? 400 : .infinity) // Limit width for the VStack
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Helper function to check if the device is an iPad
    private func isIpad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}
