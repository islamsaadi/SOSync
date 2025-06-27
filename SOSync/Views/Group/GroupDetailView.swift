import SwiftUI
import CoreLocation
import FirebaseDatabase

struct GroupDetailView: View {
    let group: SafetyGroup
    @ObservedObject var groupViewModel: GroupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var locationManager = LocationManager()
    @Environment(\.dismiss) var dismiss
    
    @State private var showInviteUser = false
    @State private var showGroupSettings = false
    @State private var showingSafetyCheckAlert = false
    @State private var showingSOSConfirmation = false
    @State private var errorAlert: GroupDetailAlertItem?
    
    private var isAdmin: Bool {
        guard let currentUserId = authViewModel.currentUser?.id else { return false }
        return currentUserId == group.adminId
    }
    
    private var currentUserId: String {
        return authViewModel.currentUser?.id ?? ""
    }
    
    /// Pull the latest version of this group from the VM
    private var currentGroup: SafetyGroup {
        let foundGroup = groupViewModel.groups.first { $0.id == group.id }
        return foundGroup ?? group
    }
    
    /// Active safety check for this group - ENHANCED logic
    private var activeSafetyCheck: SafetyCheck? {
        let currentGroupId = currentGroup.id
        
        // First check if group status indicates we should have an active safety check
        let shouldShowSafetyCheck = currentGroup.currentStatus == .checkingStatus
        
        if shouldShowSafetyCheck {
            print("🎯 Group is in checkingStatus - looking for pending safety check")
        }
        
        let pendingChecks = groupViewModel.safetyChecks.filter { check in
            check.groupId == currentGroupId && check.status == .pending
        }
        
        let activeCheck = pendingChecks.first
        
        if let check = activeCheck, shouldShowSafetyCheck {
            // Force reload safety checks if group says we should have one but we don't
            Task {
                await groupViewModel.forceReloadSafetyChecks(groupId: currentGroupId)
            }
        }
        
        return activeCheck
    }
    
    /// Check if current user has responded to active safety check - ENHANCED logic
    private var hasRespondedToActiveCheck: Bool {
        guard let activeCheck = activeSafetyCheck else {
            // If group is in checking status but no active check, user hasn't responded
            if currentGroup.currentStatus == .checkingStatus {
                print("🎯 Group in checkingStatus but no active check - user has not responded")
                return false
            }
            return false
        }
        guard let userId = authViewModel.currentUser?.id else { return false }
        
        let hasResponse = activeCheck.responses[userId] != nil
        print("🎯 User \(userId) has responded to check \(activeCheck.id): \(hasResponse)")
        
        return hasResponse
    }
    
    /// Check if current user is the initiator of active safety check
    private var isInitiatorOfActiveCheck: Bool {
        guard let activeCheck = activeSafetyCheck else { return false }
        guard let userId = authViewModel.currentUser?.id else { return false }
        return activeCheck.initiatedBy == userId
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: – Status Card
                    GroupStatusCard(group: currentGroup)
                    
                    // MARK: – Active Safety Check - ENHANCED visibility logic
                    // Show if we have a pending check OR if group status indicates checking
                    if let activeCheck = activeSafetyCheck {
                        ActiveSafetyCheckCard(
                            safetyCheck: activeCheck,
                            group: currentGroup,
                            groupViewModel: groupViewModel
                        )
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: activeSafetyCheck?.id)
                    } else if currentGroup.currentStatus == .checkingStatus {
                        // Show loading state if group is checking but we don't have the safety check yet
                        VStack(spacing: 12) {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading safety check...")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        .onAppear {
                            // Force reload when this loading state appears
                            Task {
                                print("🔄 Safety check loading state appeared - forcing reload")
                                await groupViewModel.forceReloadSafetyChecks(groupId: currentGroup.id)
                            }
                        }
                    }

                    // MARK: – SOS Alerts
                    sosAlertsSection
                    
                    // MARK: – Quick Actions - ENHANCED with safety check awareness
                    quickActionsSection
                    
                    // Show hint if not enough members
                    if currentGroup.members.count <= 1 {
                        Text("Add more members to enable safety features")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // MARK: – Members Section
                    membersSection
                }
                .padding(.vertical)
            }
            .navigationTitle(currentGroup.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isAdmin {
                        HStack(spacing: 12) {
                            // Pending invitations badge
                            if !groupViewModel.pendingInvitations.isEmpty {
                                Button {
                                    loadPendingInvitationsAndShowSettings()
                                } label: {
                                    ZStack {
                                        Image(systemName: "envelope.fill")
                                            .foregroundStyle(.blue)
                                        
                                        // Badge
                                        Text("\(groupViewModel.pendingInvitations.count)")
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 8, y: -8)
                                    }
                                }
                            }
                            
                            Button {
                                loadPendingInvitationsAndShowSettings()
                            } label: {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showInviteUser) {
                InviteUserView(group: currentGroup, groupViewModel: groupViewModel)
            }
            .sheet(isPresented: $showGroupSettings) {
                GroupSettingsView(group: currentGroup, groupViewModel: groupViewModel, onGroupDeleted: {
                    // This runs when group is deleted
                    dismiss() // Goes back to groups list
                })
            }
            .alert("Initiate Safety Check?", isPresented: $showingSafetyCheckAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Send") {
                    handleSafetyCheckInitiation()
                }
            } message: {
                Text("This will ask all members to confirm they're safe.")
            }
            .alert("Send SOS Alert?", isPresented: $showingSOSConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Send SOS", role: .destructive) {
                    handleSOSAlert()
                }
            } message: {
                Text("This will immediately alert all members and share your location.")
            }
            .alert(item: $errorAlert) { alertItem in
                Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                setupView()
            }
            .refreshable {
                await refreshData()
            }
            .onChange(of: groupViewModel.activeSOSAlerts.count) { oldCount, newCount in
                print("🔄 SOS alerts count changed from \(oldCount) to \(newCount)")
                if newCount > oldCount {
                    print("✅ New SOS alert detected!")
                }
            }
            .onChange(of: currentGroup.currentStatus) { oldStatus, newStatus in
                print("🔄 Group status changed from \(oldStatus) to \(newStatus)")
                
                if newStatus == .emergency && groupViewModel.activeSOSAlerts.isEmpty {
                    print("🔄 Group is emergency but no SOS alerts - force reloading")
                    Task {
                        await groupViewModel.forceReloadSOSAlerts(groupId: currentGroup.id)
                    }
                }
                
                if newStatus == .checkingStatus && activeSafetyCheck == nil {
                    print("🔄 Group switched to checkingStatus - force reloading safety checks")
                    Task {
                        await groupViewModel.forceReloadSafetyChecks(groupId: currentGroup.id)
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var sosAlertsSection: some View {
        let activeAlerts = groupViewModel.activeSOSAlerts
        let debugInfo = "Group: \(currentGroup.id), Alerts: \(activeAlerts.count), Status: \(currentGroup.currentStatus)"
        
        // Debug info (remove in production)
        if !activeAlerts.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("DEBUG: \(debugInfo)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        
        if !activeAlerts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("ACTIVE EMERGENCY ALERTS (\(activeAlerts.count))")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal)
                
                ForEach(activeAlerts) { alert in
                    SOSAlertCard(
                        alert: alert,
                        groupViewModel: groupViewModel,
                        isAdmin: isAdmin,
                        currentUserId: currentUserId
                    )
                    .id("sos-\(alert.id)")  // Stable ID for proper updates
                }
            }
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.05))
            .cornerRadius(16)
            .padding(.horizontal)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .opacity
            ))
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: activeAlerts.count)
        } else if currentGroup.currentStatus == .emergency {
            // Show loading state if group is emergency but no SOS alerts loaded yet
            VStack(spacing: 12) {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading emergency alerts...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.horizontal)
            .onAppear {
                // Force reload SOS alerts when loading state appears
                Task {
                    print("🔄 Emergency status but no alerts - forcing SOS reload")
                    if let groupId = currentGroup.id as String? {
                        await groupViewModel.forceReloadSOSAlerts(groupId: groupId)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        HStack(spacing: 16) {
            Button {
                handleSafetyCheckButtonTap()
            } label: {
                quickAction(
                    icon: "checkmark.shield",
                    text: "Safety Check",
                    color: .blue,
                    disabled: currentGroup.members.count <= 1 || currentGroup.currentStatus == .checkingStatus
                )
            }
            .disabled(currentGroup.members.count <= 1 || currentGroup.currentStatus == .checkingStatus)
            
            Button {
                handleSOSButtonTap()
            } label: {
                quickAction(
                    icon: "exclamationmark.triangle.fill",
                    text: "SOS",
                    color: .red,
                    disabled: currentGroup.members.count <= 1
                )
            }
            .disabled(currentGroup.members.count <= 1)
        }
        .padding(.horizontal)
        .frame(minWidth: 0, maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Members (\(currentGroup.members.count))")
                    .font(.headline)
                Spacer()
                Button { showInviteUser = true } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
            .padding(.horizontal)
            
            if groupViewModel.groupMembers.isEmpty {
                // Show loading state
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading members...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            } else {
                ForEach(groupViewModel.groupMembers) { member in
                    MemberRowView(
                        member: member,
                        isAdmin: member.id == currentGroup.adminId,
                        isCurrentUser: member.id == currentUserId
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func quickAction(icon: String, text: String, color: Color, disabled: Bool = false) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(disabled ? Color.secondary : Color.white)
            Text(text)
                .font(.caption)
                .foregroundStyle(disabled ? Color.secondary : Color.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(disabled ? Color(.systemGray4) : color)
        .cornerRadius(12)
        .opacity(disabled ? 0.6 : 1.0)
    }
    
    private func handleSafetyCheckButtonTap() {
        if currentGroup.members.count <= 1 {
            errorAlert = GroupDetailAlertItem(
                title: "Cannot Start Safety Check",
                message: "You need at least 2 members in the group to start a safety check."
            )
        } else if currentGroup.currentStatus == .checkingStatus {
            errorAlert = GroupDetailAlertItem(
                title: "Safety Check Already Active",
                message: "There's already an active safety check for this group. Please wait for it to complete."
            )
        } else {
            showingSafetyCheckAlert = true
        }
    }
    
    private func handleSOSButtonTap() {
        if currentGroup.members.count <= 1 {
            errorAlert = GroupDetailAlertItem(
                title: "Cannot Send SOS",
                message: "You need at least 2 members in the group to send an SOS alert."
            )
        } else {
            showingSOSConfirmation = true
        }
    }
    
    private func handleSafetyCheckInitiation() {
        Task {
            guard let userId = authViewModel.currentUser?.id else { return }
            
            let success = await groupViewModel.inititateSafetyCheck(
                groupId: currentGroup.id,
                initiatedBy: userId
            )
            
            if !success {
                if let error = groupViewModel.errorMessage {
                    await MainActor.run {
                        errorAlert = GroupDetailAlertItem(
                            title: "Cannot Start Safety Check",
                            message: error
                        )
                    }
                }
            }
            
            await groupViewModel.forceReloadSafetyChecks(groupId: currentGroup.id)
        }
    }
    
    private func handleSOSAlert() {
        Task {
            guard let userId = authViewModel.currentUser?.id else { return }
            
            // Ensure we have location
            if locationManager.lastLocation == nil {
                locationManager.requestLocation()
                // Give it a moment to get location
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            
            guard let location = locationManager.lastLocation else {
                await MainActor.run {
                    errorAlert = GroupDetailAlertItem(
                        title: "Location Required",
                        message: "Please enable location services to send SOS alerts."
                    )
                }
                return
            }
            
            let locationData = LocationData(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                address: nil
            )
            
            let success = await groupViewModel.sendSOSAlert(
                groupId: currentGroup.id,
                userId: userId,
                location: locationData
            )
            
            if !success {
                if let error = groupViewModel.errorMessage {
                    await MainActor.run {
                        errorAlert = GroupDetailAlertItem(
                            title: "Cannot Send SOS",
                            message: error
                        )
                    }
                }
            }
        }
    }
    
    // Enhanced setupView function
    private func setupView() {
        groupViewModel.setCurrentGroup(currentGroup)
        
        // Force load all data every time we enter
        Task {
            await groupViewModel.loadGroupMembers(group: currentGroup)
            await groupViewModel.forceReloadSafetyChecks(groupId: currentGroup.id)
            
            // Also force reload SOS alerts
            await groupViewModel.forceReloadSOSAlerts(groupId: currentGroup.id)
            
            // Load pending invitations if admin
            if isAdmin {
                await groupViewModel.loadPendingInvitations(groupId: currentGroup.id)
            }
            
            // Debug current state
            await MainActor.run {
                let alerts = groupViewModel.activeSOSAlerts
                print("🎯 Setup complete - Active SOS alerts: \(alerts.count)")
                print("🎯 Group status: \(currentGroup.currentStatus)")
                for alert in alerts {
                    print("🎯 Alert: \(alert.id), User: \(alert.userId), Active: \(alert.isActive)")
                }
            }
        }
        locationManager.requestLocation()
    }

    // Enhanced refreshData function
    private func refreshData() async {
        await groupViewModel.loadGroupMembers(group: currentGroup)
        await groupViewModel.forceReloadSafetyChecks(groupId: currentGroup.id)
        await groupViewModel.forceReloadSOSAlerts(groupId: currentGroup.id)
        
        // Refresh pending invitations if admin
        if isAdmin {
            await groupViewModel.loadPendingInvitations(groupId: currentGroup.id)
        }
    }
    
    private func loadPendingInvitationsAndShowSettings() {
        Task {
            await groupViewModel.loadPendingInvitations(groupId: currentGroup.id)
            await MainActor.run {
                showGroupSettings = true
            }
        }
    }
}

// MARK: – Alert Helper
struct GroupDetailAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// ——————————————————————————————————
// MARK: – Inline Subviews
struct GroupStatusCard: View {
    let group: SafetyGroup
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.system(size: 50))
                .foregroundStyle(statusColor)
                .scaleEffect(group.currentStatus == .emergency ? 1.1 : 1.0)
                .animation(
                    group.currentStatus == .emergency
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: group.currentStatus
                )
            
            Text(statusText)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(statusTextColor)
            
            if let ts = group.lastSafetyCheck {
                Text("Last check \(Date(timeIntervalSince1970: ts), style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Additional status information
            if group.currentStatus == .emergency {
                Text("Emergency situation detected")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            } else if group.currentStatus == .allSafe {
                Text("All members confirmed safe")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.3), lineWidth: group.currentStatus == .emergency ? 2 : 1)
        )
        .padding(.horizontal)
    }
    
    private var statusIcon: String {
        switch group.currentStatus {
        case .normal:        return "shield.checkered"
        case .checkingStatus:return "clock.arrow.circlepath"
        case .allSafe:       return "checkmark.shield.fill"
        case .emergency:     return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusColor: Color {
        switch group.currentStatus {
        case .normal:        return Color.blue
        case .checkingStatus:return Color.orange
        case .allSafe:       return Color.green
        case .emergency:     return Color.red
        }
    }
    
    private var statusTextColor: Color {
        switch group.currentStatus {
        case .emergency:     return Color.red
        default:             return Color.primary
        }
    }
    
    private var statusText: String {
        switch group.currentStatus {
        case .normal:        return "All Normal"
        case .checkingStatus:return "Checking Status..."
        case .allSafe:       return "Everyone is Safe ✓"
        case .emergency:     return "EMERGENCY ALERT!"
        }
    }
}
