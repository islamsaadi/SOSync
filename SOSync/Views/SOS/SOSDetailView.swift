//
//  SOSDetailView.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//

import SwiftUI

// MARK: - SOS Detail View
struct SOSDetailView: View {
    let group: SafetyGroup
    @ObservedObject var groupViewModel: GroupViewModel
    @ObservedObject var locationManager: LocationManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var message = ""
    @State private var isSending = false
    
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
        }
    }
    
    private func sendSOS() {
        guard let userId = authViewModel.currentUser?.id,
              let location = locationManager.lastLocation else { return }
        
        isSending = true
        
        let locationData = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            address: nil
        )
        
        Task {
            let success = await groupViewModel.sendSOSAlert(
                groupId: group.id,
                userId: userId,
                location: locationData,
                message: message.isEmpty ? nil : message
            )
            
            await MainActor.run {
                isSending = false
                if success {
                    dismiss()
                }
            }
        }
    }
}
