//
//  SOSAlertCard.swift
//  SOSync
//
//  Created by Islam Saadi on 22/06/2025.
//

import SwiftUI
import CoreLocation
import MapKit
import FirebaseDatabase

// MARK: - SOS Alert Card
struct SOSAlertCard: View {
    let alert: SOSAlert
    @ObservedObject var groupViewModel: GroupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    let isAdmin: Bool
    let currentUserId: String
    
    @State private var alertUser: User?
    @State private var isCancelling = false
    @State private var showCancelConfirmation = false
    @State private var errorAlert: SOSAlertErrorItem?
    
    var isMyAlert: Bool {
        currentUserId == alert.userId
    }
    
    var canCancelSOS: Bool {
        if isMyAlert {
            return true // User can always cancel their own SOS
        }
        
        if isAdmin {
            let now = Date().timeIntervalSince1970
            let twentyFourHours: Double = 24 * 60 * 60
            return (now - alert.timestamp) > twentyFourHours
        }
        
        return false
    }
    
    var hoursUntilAdminCanCancel: Int {
        guard isAdmin && !isMyAlert else { return 0 }
        let now = Date().timeIntervalSince1970
        let twentyFourHours: Double = 24 * 60 * 60
        let timeElapsed = now - alert.timestamp
        let timeRemaining = twentyFourHours - timeElapsed
        return max(0, Int(timeRemaining / 3600))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with timestamp and urgency indicator
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.red)
                            .font(.title2)
                        Text("EMERGENCY SOS")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.red)
                    }
                    
                    Text("Alert sent \(Date(timeIntervalSince1970: alert.timestamp), style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                
                Spacer()
                
                // Pulsing red indicator
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .scaleEffect(1.5)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: true)
            }
            
            if let user = alertUser {
                VStack(alignment: .leading, spacing: 12) {
                    // User Information
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundStyle(Color.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(user.username)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                if isMyAlert {
                                    Text("(You)")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.2))
                                        .foregroundStyle(Color.red)
                                        .cornerRadius(4)
                                }
                            }
                            
                            HStack {
                                Image(systemName: "phone.fill")
                                    .font(.caption)
                                Text(user.phoneNumber)
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(Color.primary)
                        }
                        
                        Spacer()
                    }
                    
                    // Message if available
                    if let message = alert.message, !message.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Emergency Details:")
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
                    
                    // Location Map
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Location:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.secondary)
                        
                        MapSnapshotView(location: alert.location)
                            .frame(height: 150)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red, lineWidth: 2)
                            )
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        if !isMyAlert {
                            // Emergency response buttons for other members
                            HStack(spacing: 12) {
                                Button {
                                    if let url = URL(string: "tel://\(user.phoneNumber)") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("Call Now", systemImage: "phone.fill")
                                        .frame(maxWidth: .infinity)
                                        .foregroundStyle(Color.white)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.red)
                                .controlSize(.large)
                                
                                Button {
                                    let coordinate = alert.location.coordinate
                                    let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                                    mapItem.name = "\(user.username)'s Emergency Location"
                                    mapItem.openInMaps()
                                } label: {
                                    Label("Directions", systemImage: "location.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(Color.blue)
                                .controlSize(.large)
                            }
                        }
                        
                        // Cancel SOS button
                        if canCancelSOS {
                            Button {
                                showCancelConfirmation = true
                            } label: {
                                if isCancelling {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                                            .scaleEffect(0.8)
                                        Text("Cancelling...")
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Label(
                                        isMyAlert ? "Cancel My SOS" : "Cancel SOS (Admin)",
                                        systemImage: "xmark.circle.fill"
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.orange)
                            .controlSize(.large)
                            .disabled(isCancelling)
                        } else if isAdmin && !isMyAlert {
                            // Show countdown for admin
                            VStack(spacing: 4) {
                                Text("Admin can cancel in \(hoursUntilAdminCanCancel) hours")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button {
                                    // Disabled button to show it exists
                                } label: {
                                    Label("Cancel SOS (Admin)", systemImage: "xmark.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(Color.gray)
                                .disabled(true)
                            }
                        }
                    }
                }
            } else {
                // Loading state
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading emergency details...")
                        .font(.callout)
                        .foregroundStyle(Color.secondary)
                }
                .padding()
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.red.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(16)
        .padding(.horizontal)
        .alert("Cancel SOS Alert", isPresented: $showCancelConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm Cancel", role: .destructive) {
                cancelSOS()
            }
        } message: {
            if isMyAlert {
                Text("Are you sure you want to cancel your SOS alert? This will notify all group members that the emergency is over.")
            } else {
                Text("As an admin, you can cancel this SOS alert after 24 hours. This action will notify all group members.")
            }
        }
        .alert(item: Binding<SOSAlertErrorItem?>(
            get: { errorAlert },
            set: { errorAlert = $0 }
        )) { alertItem in
            Alert(
                title: Text(alertItem.title),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            loadUserData()
        }
    }
    
    private func loadUserData() {
        Task {
            do {
                let database = Database.database().reference()
                let userData = try await database.child("users").child(alert.userId).getData()
                if let userDict = userData.value as? [String: Any],
                   let jsonData = try? JSONSerialization.data(withJSONObject: userDict),
                   let user = try? JSONDecoder().decode(User.self, from: jsonData) {
                    await MainActor.run {
                        self.alertUser = user
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorAlert = SOSAlertErrorItem(
                        title: "Error",
                        message: "Failed to load user information: \(error.localizedDescription)"
                    )
                }
            }
        }
    }
    
    private func cancelSOS() {
        guard !isCancelling else { return }
        
        // Check permissions first
        let now = Date().timeIntervalSince1970
        let twentyFourHours: Double = 24 * 60 * 60
        
        let canCancel = isMyAlert || (isAdmin && (now - alert.timestamp) > twentyFourHours)
        
        guard canCancel else {
            if isAdmin {
                let hoursLeft = Int((twentyFourHours - (now - alert.timestamp)) / 3600)
                errorAlert = SOSAlertErrorItem(
                    title: "Cannot Cancel SOS",
                    message: "Admins can cancel SOS alerts after 24 hours. \(hoursLeft) hours remaining."
                )
            } else {
                errorAlert = SOSAlertErrorItem(
                    title: "Cannot Cancel SOS",
                    message: "You can only cancel your own SOS alerts."
                )
            }
            return
        }
        
        isCancelling = true
        
        Task {
            do {
                let database = Database.database().reference()
                
                print("🚨 Starting SOS cancellation for alert: \(alert.id)")
                print("🚨 Alert user: \(alert.userId)")
                print("🚨 Alert group: \(alert.groupId)")
                
                // Mark the SOS as inactive
                try await database.child("sosAlerts").child(alert.id).child("isActive").setValue(false)
                print("✅ SOS alert marked as inactive")
                
                // ✅ Step 1: Check if there are other active SOS alerts for this group
                let groupSOSSnapshot = try await database.child("sosAlerts")
                    .queryOrdered(byChild: "groupId")
                    .queryEqual(toValue: alert.groupId)
                    .getData()
                
                var hasOtherActiveAlerts = false
                let enumerator = groupSOSSnapshot.children
                while let child = enumerator.nextObject() as? DataSnapshot {
                    if let alertDict = child.value as? [String: Any],
                       let isActive = alertDict["isActive"] as? Bool,
                       isActive && child.key != alert.id {
                        hasOtherActiveAlerts = true
                        break
                    }
                }
                
                print("🔍 Other active SOS alerts exist: \(hasOtherActiveAlerts)")
                
                // ✅ Step 2: Check for active safety checks - ENHANCED to find the correct one
                let safetyChecksSnapshot = try await database.child("safetyChecks").getData()
                var activeSafetyCheck: [String: Any]?
                var activeSafetyCheckId: String?
                var wasResponseToSafetyCheck = false
                
                print("🔍 Checking all safety checks...")
                
                let safetyEnumerator = safetyChecksSnapshot.children
                while let child = safetyEnumerator.nextObject() as? DataSnapshot {
                    if let checkDict = child.value as? [String: Any],
                       let checkGroupId = checkDict["groupId"] as? String,
                       checkGroupId == alert.groupId {
                        
                        let checkId = child.key
                        let status = checkDict["status"] as? String ?? "pending"
                        
                        print("🔍 Found safety check: \(checkId), status: \(status)")
                        
                        if status == "pending" {
                            activeSafetyCheck = checkDict
                            activeSafetyCheckId = checkId
                            
                            // ✅ CRITICAL FIX: Check if this SOS user has a response in this safety check
                            if let responses = checkDict["responses"] as? [String: Any],
                               let userResponse = responses[alert.userId] as? [String: Any],
                               let responseStatus = userResponse["status"] as? String,
                               responseStatus == "sos" {
                                
                                print("✅ FOUND: This SOS was a response to safety check \(checkId)")
                                wasResponseToSafetyCheck = true
                                break
                            }
                        }
                    }
                }
                
                // ✅ Step 3: If this SOS was a response to a safety check, remove the response
                if wasResponseToSafetyCheck,
                   let checkId = activeSafetyCheckId {
                    
                    print("🔄 Removing SOS response from safety check: \(checkId)")
                    print("🔄 Removing response for user: \(alert.userId)")
                    
                    try await database
                        .child("safetyChecks")
                        .child(checkId)
                        .child("responses")
                        .child(alert.userId)
                        .removeValue()
                    
                    print("✅ Successfully removed SOS response from safety check")
                    
                    // ✅ Force reload the safety check to update UI immediately
                    await groupViewModel.forceReloadSafetyChecks(groupId: alert.groupId)
                }
                
                // ✅ Step 4: If there are still other active SOS alerts, keep emergency status
                if hasOtherActiveAlerts {
                    print("🚨 Other active SOS alerts exist - keeping emergency status")
                    await MainActor.run {
                        isCancelling = false
                    }
                    return
                }
                
                // ✅ Step 5: Determine the appropriate group status
                let newGroupStatus: String
                
                if let activeCheck = activeSafetyCheck,
                   let checkId = activeSafetyCheckId {
                    print("🔍 Active safety check found - analyzing remaining responses...")
                    
                    // Get group members
                    let groupSnapshot = try await database.child("groups").child(alert.groupId).getData()
                    guard let groupDict = groupSnapshot.value as? [String: Any],
                          let members = groupDict["members"] as? [String] else {
                        throw NSError(domain: "CancelSOS", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not get group members"])
                    }
                    
                    // Get CURRENT responses (after potentially removing the SOS response above)
                    let currentResponsesSnapshot = try await database
                        .child("safetyChecks")
                        .child(checkId)
                        .child("responses")
                        .getData()
                    
                    let currentResponses = currentResponsesSnapshot.value as? [String: Any] ?? [:]
                    let responseCount = currentResponses.count
                    
                    print("🔍 Safety check status after SOS removal: \(responseCount)/\(members.count) responses")
                    
                    // Debug: Print all current responses
                    for (userId, response) in currentResponses {
                        if let resp = response as? [String: Any],
                           let status = resp["status"] as? String {
                            print("🔍 Response from \(userId): \(status)")
                        }
                    }
                    
                    // Check if all members have responded
                    let allResponded = members.allSatisfy { memberId in
                        currentResponses[memberId] != nil
                    }
                    
                    if allResponded {
                        // All responded - check if all are safe (no more SOS responses)
                        var allSafe = true
                        for (_, responseData) in currentResponses {
                            if let resp = responseData as? [String: Any],
                               let status = resp["status"] as? String,
                               status == "sos" {
                                allSafe = false
                                break
                            }
                        }
                        
                        newGroupStatus = allSafe ? "allSafe" : "emergency"
                        print("🔍 All responded after SOS removal - setting status to: \(newGroupStatus)")
                        
                        // If all safe, also mark the safety check as completed
                        if allSafe {
                            try await database
                                .child("safetyChecks")
                                .child(checkId)
                                .child("status")
                                .setValue("allSafe")
                            print("✅ Marked safety check as completed (allSafe)")
                        }
                    } else {
                        // Not all responded - keep checking status
                        newGroupStatus = "checkingStatus"
                        print("🔍 Not all responded after SOS removal - keeping checkingStatus")
                    }
                } else {
                    // No active safety check and no other SOS alerts - return to normal
                    newGroupStatus = "normal"
                    print("🔍 No active safety check or SOS alerts - setting to normal")
                }
                
                // ✅ Step 6: Update group status
                try await database.child("groups").child(alert.groupId).child("currentStatus").setValue(newGroupStatus)
                print("✅ Group status updated to: \(newGroupStatus)")
                
                // ✅ Step 7: Force reload safety checks to update the UI
                await groupViewModel.forceReloadSafetyChecks(groupId: alert.groupId)
                print("✅ Forced reload of safety checks")
                
                await MainActor.run {
                    isCancelling = false
                }
                
            } catch {
                print("❌ Error cancelling SOS: \(error)")
                await MainActor.run {
                    isCancelling = false
                    errorAlert = SOSAlertErrorItem(
                        title: "Cannot Cancel SOS",
                        message: "Failed to cancel SOS alert: \(error.localizedDescription)"
                    )
                }
            }
        }
    }
    
}
// MARK: - Alert Helper for SOSAlertCard
struct SOSAlertErrorItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
