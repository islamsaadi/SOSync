import SwiftUI

struct SOSDetailView: View {
    let group: SafetyGroup
    @ObservedObject var groupViewModel: GroupViewModel
    @ObservedObject var locationManager: LocationManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var message = ""
    @State private var isSending = false
    @State private var errorAlert: SOSDetailAlertItem?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Send SOS to \(group.name)")
                    .font(.headline)
                
                TextField("Optional message", text: $message, axis: .vertical)
                    .lineLimit(3...6)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                Button {
                    sendSOS()
                } label: {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Label("Send SOS Alert", systemImage: "exclamationmark.triangle.fill")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(.white)
                .background(Color.red)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(isSending)
                
                Spacer()
            }
            .navigationTitle("SOS Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(item: $errorAlert) { alertItem in
                Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func sendSOS() {
        guard let userId = authViewModel.currentUser?.id else {
            errorAlert = SOSDetailAlertItem(
                title: "Authentication Error",
                message: "Unable to identify user. Please try again."
            )
            return
        }
        
        guard let location = locationManager.lastLocation else {
            errorAlert = SOSDetailAlertItem(
                title: "Location Required",
                message: "Please enable location services to send SOS alerts."
            )
            return
        }
        
        isSending = true
        
        Task {
            let success = await groupViewModel.sendSOSAlertWithCLLocation(
                groupId: group.id,
                userId: userId,
                location: location,
                message: message.isEmpty ? nil : message
            )
            
            await MainActor.run {
                isSending = false
                if success {
                    dismiss()
                } else {
                    errorAlert = SOSDetailAlertItem(
                        title: "SOS Failed",
                        message: groupViewModel.errorMessage ?? "Failed to send SOS alert"
                    )
                }
            }
        }
    }
}

struct SOSDetailAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
