import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ScheduleView: View {
    @State private var selectedDate = Date()
    @State private var blockoutDates: [String: [Date]] = [:] // Map of user IDs to blockout dates
    @State private var errorMessage: String = ""
    
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
            .padding()

            // Add Blockout Date Button
            Button(action: {
                addBlockoutDate()
            }) {
                Text("Add Blockout Date")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            // List of Current Blockout Dates (for the current user)
            if let currentUserDates = blockoutDates[Auth.auth().currentUser?.uid ?? ""] {
                List {
                    ForEach(currentUserDates, id: \.self) { date in
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
            } else {
                Text("No blockout dates added.")
                    .foregroundColor(.gray)
                    .padding()
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
                self.errorMessage = "Error fetching data: \(error.localizedDescription)"
                return
            }

            var dates = snapshot?.data()?["blockout_dates"] as? [Timestamp] ?? []
            if !dates.contains(where: { $0.dateValue() == self.selectedDate }) {
                dates.append(Timestamp(date: self.selectedDate))
                userRef.updateData(["blockout_dates": dates]) { error in
                    if let error = error {
                        self.errorMessage = "Error updating data: \(error.localizedDescription)"
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
                self.errorMessage = "Error fetching data: \(error.localizedDescription)"
                return
            }

            var dates = snapshot?.data()?["blockout_dates"] as? [Timestamp] ?? []
            if let index = dates.firstIndex(where: { $0.dateValue() == date }) {
                dates.remove(at: index)
                userRef.updateData(["blockout_dates": dates]) { error in
                    if let error = error {
                        self.errorMessage = "Error updating data: \(error.localizedDescription)"
                    } else {
                        self.fetchBlockoutDates()
                    }
                }
            }
        }
    }

    // Fetch all users' blockout dates
    private func fetchBlockoutDates() {
        guard let userID = Auth.auth().currentUser?.uid else {
            self.errorMessage = "User is not logged in."
            return
        }

        db.collection("users").document(userID).getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Error fetching data: \(error.localizedDescription)"
                return
            }

            guard let data = snapshot?.data(),
                  let timestamps = data["blockout_dates"] as? [Timestamp] else {
                self.errorMessage = "No blockout dates found."
                return
            }

            self.blockoutDates[userID] = timestamps.map { $0.dateValue() }
            print("Fetched blockout dates: \(self.blockoutDates)")
        }
    }


    // Helper: Format a date for display
    private func dateFormatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}
