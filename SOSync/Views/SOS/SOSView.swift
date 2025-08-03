import SwiftUI

struct SOSView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var groupViewModel = GroupViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var selectedGroup: SafetyGroup?
    @State private var sosMessage = ""
    @State private var errorAlert: SOSViewAlertItem?
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
            .alert(item: $errorAlert) { alertItem in
                Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("OK"))
                )
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
    
    // MVVM Fix: Call ViewModel method instead of implementing logic here
    private func sendSOSToAllGroups() {
        guard let userId = authViewModel.currentUser?.id else {
            errorAlert = SOSViewAlertItem(
                title: "Authentication Error",
                message: "Unable to identify user. Please try again."
            )
            return
        }
        
        guard let location = locationManager.lastLocation else {
            errorAlert = SOSViewAlertItem(
                title: "Location Required",
                message: "Please enable location services to send SOS alerts."
            )
            return
        }
        
        Task {
            do {
                try await groupViewModel.sendSOSToAllGroups(
                    userId: userId,
                    location: location,
                    message: "Emergency SOS sent to all groups"
                )
            } catch {
                await MainActor.run {
                    errorAlert = SOSViewAlertItem(
                        title: "SOS Failed",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }
}

struct SOSViewAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
