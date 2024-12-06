import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ScheduleView: View {
    let orgId: String // Organization ID passed to this view
    @State private var selectedDate = Date()
    @State private var blockoutDates: [Date] = [] // List of blockout dates for the current user
    @State private var errorMessage: String = ""
    @State private var isLoading = false // Loading state

    private let db = Firestore.firestore()

    var body: some View {
        VStack {
            // Calendar View
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .scaleEffect(isIpad() ? 2.0 : 1.0)
            .padding()
            
            Spacer().frame(height: isIpad() ? 200 : 20)
            // Add Blockout Date Button
            Button(action: {
                addBlockoutDate()
            }) {
                Text("Add Blockout Date")
                    .frame(maxWidth: isIpad() ? 400 :.infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            // List of Current Blockout Dates
            if blockoutDates.isEmpty {
                Text("No blockout dates added.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List {
                    ForEach(blockoutDates, id: \.self) { date in
                        HStack {
                            Text(dateFormatted(date: date))
                                .font(.body)
                            Spacer()
                            Button(action: {
                                removeBlockoutDate(date: date)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle()) // Prevents swipe gesture conflicts
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }

            // Error Message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle("My Schedule")
        .onAppear {
            fetchBlockoutDates()
        }
        .alert(isPresented: .constant(!errorMessage.isEmpty)) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }

    // Add blockout date for the current user
    private func addBlockoutDate() {
        guard let userID = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to add blockout dates."
            return
        }

        let userRef = db.collection("users").document(userID)
        userRef.getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Error fetching user data: \(error.localizedDescription)"
                return
            }

            var dates = snapshot?.data()?["blockout_dates"] as? [Timestamp] ?? []
            if !dates.contains(where: { $0.dateValue() == self.selectedDate }) {
                dates.append(Timestamp(date: self.selectedDate))
                userRef.updateData(["blockout_dates": dates]) { error in
                    if let error = error {
                        self.errorMessage = "Error updating blockout dates: \(error.localizedDescription)"
                    } else {
                        self.fetchBlockoutDates()
                    }
                }
            }
        }
    }

    // Remove a blockout date for the current user
    private func removeBlockoutDate(date: Date) {
        guard let userID = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to remove blockout dates."
            return
        }

        let userRef = db.collection("users").document(userID)
        userRef.getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Error fetching user data: \(error.localizedDescription)"
                return
            }

            var dates = snapshot?.data()?["blockout_dates"] as? [Timestamp] ?? []
            if let index = dates.firstIndex(where: { $0.dateValue() == date }) {
                dates.remove(at: index)
                userRef.updateData(["blockout_dates": dates]) { error in
                    if let error = error {
                        self.errorMessage = "Error updating blockout dates: \(error.localizedDescription)"
                    } else {
                        self.fetchBlockoutDates()
                    }
                }
            }
        }
    }

    // Fetch blockout dates for the current user
    private func fetchBlockoutDates() {
        guard let userID = Auth.auth().currentUser?.uid else {
            self.errorMessage = "You must be logged in."
            return
        }

        let userRef = db.collection("users").document(userID)
        userRef.getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Error fetching blockout dates: \(error.localizedDescription)"
                return
            }

            guard let data = snapshot?.data(),
                  let timestamps = data["blockout_dates"] as? [Timestamp] else {
                self.blockoutDates = []
                return
            }

            self.blockoutDates = timestamps.map { $0.dateValue() }
            print("Fetched blockout dates: \(self.blockoutDates)")
        }
    }

    // Helper: Format a date for display
    private func dateFormatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    // Helper function to check if the device is an iPad
    private func isIpad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}
