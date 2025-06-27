//
//  SOSView.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//

import SwiftUI

// MARK: - SOS View
struct SOSView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var groupViewModel = GroupViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var selectedGroup: SafetyGroup?
    @State private var sosMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Emergency button
                Button {
                    sendSOSToAllGroups()
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                        Text("EMERGENCY SOS")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Send to all groups")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .foregroundStyle(.white)
                    .background(Color.red)
                    .cornerRadius(20)
                }
                .padding(.horizontal)
                
                // Group-specific SOS
                if !groupViewModel.groups.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Send SOS to specific group")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(groupViewModel.groups) { group in
                                    Button {
                                        selectedGroup = group
                                    } label: {
                                        HStack {
                                            Text(group.name)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(12)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("SOS")
            .onAppear {
                Task {
                    if let userId = authViewModel.currentUser?.id {
                        await groupViewModel.loadUserGroups(userId: userId)
                    }
                }
                
                locationManager.requestLocation()
            }
            .sheet(item: $selectedGroup) { group in
                SOSDetailView(group: group, groupViewModel: groupViewModel, locationManager: locationManager)
            }
        }
    }
    
    private func sendSOSToAllGroups() {
        guard let userId = authViewModel.currentUser?.id,
              let location = locationManager.lastLocation else { return }
        
        let locationData = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            address: nil
        )
        
        Task {
            for group in groupViewModel.groups {
                _ = await groupViewModel.sendSOSAlert(
                    groupId: group.id,
                    userId: userId,
                    location: locationData,
                    message: "Emergency SOS sent to all groups"
                )
            }
        }
    }
}
