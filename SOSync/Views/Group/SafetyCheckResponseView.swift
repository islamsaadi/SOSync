import SwiftUI
import CoreLocation

struct SafetyCheckResponseView: View {
    let safetyCheck: SafetyCheck
    let group: SafetyGroup
    let initialResponseStatus: SafetyResponseStatus

    @ObservedObject var groupViewModel: GroupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var locationManager = LocationManager()
    @Environment(\.dismiss) var dismiss
    
    @State private var responseStatus: SafetyResponseStatus
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var errorAlert: SafetyResponseAlertItem?
    
    init(
            safetyCheck: SafetyCheck,
            group: SafetyGroup,
            groupViewModel: GroupViewModel,
            initialResponseStatus: SafetyResponseStatus
        ) {
            self.safetyCheck = safetyCheck
            self.group = group
            self.groupViewModel = groupViewModel
            self.initialResponseStatus = initialResponseStatus
            
            self._responseStatus = State(initialValue: initialResponseStatus)
        }
    
    var hasResponded: Bool {
        guard let userId = authViewModel.currentUser?.id else { return false }
        return safetyCheck.responses[userId] != nil
    }
    
    var myResponse: SafetyResponse? {
        guard let userId = authViewModel.currentUser?.id else { return nil }
        return safetyCheck.responses[userId]
    }
    
    var isInitiator: Bool {
        guard let userId = authViewModel.currentUser?.id else { return false }
        return safetyCheck.initiatedBy == userId
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.orange)
                            .scaleEffect(1.1)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: true)
                        
                        VStack(spacing: 8) {
                            Text("Safety Check Response")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            if hasResponded {
                                Text("You have already responded to this safety check")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                            } else {
                                Text("Please confirm your current safety status")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                Text("Requested \(Date(timeIntervalSince1970: safetyCheck.timestamp), style: .relative) ago")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                if isInitiator {
                                    Text("You initiated this safety check")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundStyle(.blue)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    .padding()
                    
                    if hasResponded {
                        // Already responded - show response summary
                        ResponseSummaryView(response: myResponse!)
                    } else {
                        VStack(spacing: 20) {
                            Text("How are you doing?")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 16) {
                                ResponseOptionCard(
                                    title: "I'm Safe",
                                    subtitle: "Everything is okay, no assistance needed",
                                    icon: "checkmark.shield.fill",
                                    color: .green,
                                    isSelected: responseStatus == .safe,
                                    isPrimary: true
                                ) {
                                    responseStatus = .safe
                                }
                                
                                ResponseOptionCard(
                                    title: "SOS - I Need Help",
                                    subtitle: "Emergency situation, require immediate assistance",
                                    icon: "exclamationmark.triangle.fill",
                                    color: .red,
                                    isSelected: responseStatus == .sos,
                                    isPrimary: false
                                ) {
                                    responseStatus = .sos
                                }
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Additional Information (Optional)")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    TextField(
                                        responseStatus == .sos ? "Describe your emergency..." : "Add any details...",
                                        text: $message,
                                        axis: .vertical
                                    )
                                    .lineLimit(3...6)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                    
                                    if responseStatus == .sos {
                                        Text("Your location will be shared automatically with your emergency response.")
                                            .font(.caption)
                                            .foregroundStyle(Color.red)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            
                            VStack(spacing: 8) {
                                Button {
                                    submitResponse()
                                } label: {
                                    HStack {
                                        if isSubmitting {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.9)
                                            Text("Submitting...")
                                        } else {
                                            Image(systemName: responseStatus == .safe ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                            Text(responseStatus == .safe ? "Confirm I'm Safe" : "Send SOS Alert")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(responseStatus == .safe ? Color.green : Color.red)
                                .controlSize(.large)
                                .disabled(isSubmitting)
                                .padding(.horizontal)
                                
                                if responseStatus == .sos {
                                    Text("This will immediately alert all group members")
                                        .font(.caption)
                                        .foregroundStyle(Color.red)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Group members status
                    GroupMembersStatusView(
                        safetyCheck: safetyCheck,
                        group: group,
                        groupViewModel: groupViewModel
                    )
                }
            }
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
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
            .task(id: initialResponseStatus) {
                if initialResponseStatus != .noResponse {
                    responseStatus = initialResponseStatus
                }
            }
            .onAppear {
                locationManager.requestLocation()
            }
        }
    }
    
    private func submitResponse() {
        guard let userId = authViewModel.currentUser?.id else {
            errorAlert = SafetyResponseAlertItem(title: "Error", message: "Unable to identify user")
            return
        }
        
        isSubmitting = true
        
        Task {
            // Get location if SOS
            var finalLocation: LocationData?
            if responseStatus == .sos {
                if let loc = locationManager.lastLocation {
                    finalLocation = LocationData(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude,
                        address: nil
                    )
                } else {
                    // If SOS and no location, request it
                    locationManager.requestLocation()
                    // Wait a moment for location
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    
                    // Check again
                    if let loc = locationManager.lastLocation {
                        finalLocation = LocationData(
                            latitude: loc.coordinate.latitude,
                            longitude: loc.coordinate.longitude,
                            address: nil
                        )
                    } else {
                        await MainActor.run {
                            isSubmitting = false
                            errorAlert = SafetyResponseAlertItem(
                                title: "Location Required",
                                message: "Please enable location services to send SOS alerts."
                            )
                        }
                        return
                    }
                }
            }
            
            // Submit response
            await groupViewModel.respondToSafetyCheck(
                checkId: safetyCheck.id,
                userId: userId,
                status: responseStatus,
                location: finalLocation,
                message: message.isEmpty ? nil : message
            )
            
            await MainActor.run {
                isSubmitting = false
                
                // If SOS, also send an SOS alert
                if responseStatus == .sos {
                    Task {
                        if let finalLocation = finalLocation {
                            _ = await groupViewModel.sendSOSAlert(
                                groupId: group.id,
                                userId: userId,
                                location: finalLocation,
                                message: "SOS during safety check: \(message)"
                            )
                        }
                    }
                }
                dismiss()
            }
        }
    }
}

struct ResponseOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let isPrimary: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(isSelected ? Color.white : color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? color : color.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                    )
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct ResponseSummaryView: View {
    let response: SafetyResponse
    
    var statusColor: Color {
        switch response.status {
        case .safe:
            return Color.green
        case .sos:
            return Color.red
        case .noResponse:
            return Color.gray
        }
    }
    
    var statusIcon: String {
        switch response.status {
        case .safe:
            return "checkmark.shield.fill"
        case .sos:
            return "exclamationmark.triangle.fill"
        case .noResponse:
            return "questionmark.circle.fill"
        }
    }
    
    var statusText: String {
        switch response.status {
        case .safe:
            return "You marked yourself as SAFE"
        case .sos:
            return "You sent an SOS alert"
        case .noResponse:
            return "No response recorded"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.system(size: 50))
                    .foregroundStyle(statusColor)
                
                Text(statusText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("Responded \(Date(timeIntervalSince1970: response.timestamp), style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            
            if let message = response.message, !message.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Message:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.secondary)
                    
                    Text(message)
                        .font(.callout)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }
            }
            
            if response.status == .sos, let location = response.location {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location Shared:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.secondary)
                    
                    Text("Your emergency location has been shared with all group members")
                        .font(.callout)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MVVM Fix: Updated GroupMembersStatusView
struct GroupMembersStatusView: View {
    let safetyCheck: SafetyCheck
    let group: SafetyGroup
    @ObservedObject var groupViewModel: GroupViewModel
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Group Members Status")
                    .font(.headline)
                Spacer()
                Text("\(safetyCheck.responses.count)/\(group.members.count) responded")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading member status...")
                        .font(.callout)
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal)
            } else if groupViewModel.groupMembers.isEmpty {
                Text("No members to display")
                    .font(.callout)
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    ForEach(group.members, id: \.self) { memberId in
                        if let member = groupViewModel.groupMembers.first(where: { $0.id == memberId }) {
                            MemberStatusRow(
                                member: member,
                                response: safetyCheck.responses[memberId]
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            loadMemberDetails()
        }
    }
    
    // MVVM Fix: Simplified to just call ViewModel method
    private func loadMemberDetails() {
        Task {
            await groupViewModel.loadGroupMembers(group: group)
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct MemberStatusRow: View {
    let member: User
    let response: SafetyResponse?
    
    var statusColor: Color {
        guard let response = response else { return Color.orange }
        switch response.status {
        case .safe:
            return Color.green
        case .sos:
            return Color.red
        case .noResponse:
            return Color.gray
        }
    }
    
    var statusIcon: String {
        guard let response = response else { return "clock" }
        switch response.status {
        case .safe:
            return "checkmark.circle.fill"
        case .sos:
            return "exclamationmark.triangle.fill"
        case .noResponse:
            return "questionmark.circle"
        }
    }
    
    var statusText: String {
        guard let response = response else { return "Awaiting response" }
        switch response.status {
        case .safe:
            return "Safe"
        case .sos:
            return "SOS - Emergency"
        case .noResponse:
            return "No response"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.username)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.caption)
                    Text(statusText)
                        .font(.caption)
                }
                .foregroundStyle(statusColor)
            }
            
            Spacer()
            
            if let response = response {
                Text(Date(timeIntervalSince1970: response.timestamp), style: .relative)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            } else {
                Image(systemName: "hourglass")
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct SafetyResponseAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
