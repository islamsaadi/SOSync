import SwiftUI

struct SOSView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var groupViewModel = GroupViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var selectedGroup: SafetyGroup?
    @State private var sosMessage = ""
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if isLandscape {
                    // Landscape layout
                    HStack(spacing: 20) {
                        // Emergency button on the left
                        emergencyButton
                            .frame(width: geometry.size.width * 0.4)
                        
                        // Groups list on the right
                        if !groupViewModel.groups.isEmpty {
                            groupsList
                                .frame(maxWidth: .infinity)
                        } else {
                            VStack {
                                Spacer()
                                Text("No groups available")
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                } else {
                    // Portrait layout
                    ScrollView {
                        VStack(spacing: 20) {
                            emergencyButton
                                .frame(height: 200)
                                .padding(.horizontal)
                            
                            if !groupViewModel.groups.isEmpty {
                                groupsList
                                    .padding(.bottom)
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("SOS")
            .navigationBarTitleDisplayMode(isLandscape ? .inline : .large)
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
    
    private var emergencyButton: some View {
        Button {
            sendSOSToAllGroups()
        } label: {
            VStack(spacing: isLandscape ? 12 : 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: isLandscape ? 40 : 60))
                Text("EMERGENCY SOS")
                    .font(isLandscape ? .title3 : .title2)
                    .fontWeight(.bold)
                Text("Send to all groups")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
            .background(Color.red)
            .cornerRadius(20)
        }
    }
    
    private var groupsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send SOS to specific group")
                .font(.headline)
                .padding(.horizontal, isLandscape ? 0 : 16)
            
            ScrollView {
                LazyVStack(spacing: isLandscape ? 8 : 12) {
                    ForEach(groupViewModel.groups) { group in
                        groupButton(for: group)
                            .padding(.horizontal, isLandscape ? 0 : 16)
                    }
                }
            }
        }
    }
    
    private func groupButton(for group: SafetyGroup) -> some View {
        Button {
            selectedGroup = group
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if isLandscape {
                        Text("\(group.members.count) members")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(isLandscape ? 12 : 16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
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
