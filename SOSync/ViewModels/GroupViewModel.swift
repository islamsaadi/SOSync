import Foundation
import FirebaseDatabase
import FirebaseAuth
import CoreLocation

@MainActor
class GroupViewModel: ObservableObject {
    // MARK: - Published state
    @Published var groups: [SafetyGroup] = []
    @Published var currentGroup: SafetyGroup?
    @Published var groupMembers: [User] = []
    @Published var pendingInvitations: [GroupInvitation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var safetyChecks: [SafetyCheck] = []

    // MARK: - Private storage & listeners
    private let database = Database.database().reference()
    private var groupListeners: [String: DatabaseHandle] = [:]
    private var safetyCheckListeners: [String: DatabaseHandle] = [:]
    private var sosAlertListeners: [String: DatabaseHandle] = [:]
    private var pendingInvitationsListener: DatabaseHandle?
    
    @Published var sosAlertsByGroup: [String: [SOSAlert]] = [:]
    
    var activeSOSAlerts: [SOSAlert] {
        guard let currentGroupId = currentGroup?.id else { return [] }
        return sosAlertsByGroup[currentGroupId] ?? []
    }

    // MARK: - Public API

    func loadUserGroups(userId: String) async {
        isLoading = true
        removeAllListeners()
        groups.removeAll()

        do {
            let snapshot = try await database.child("groups").getData()
            let enumerator = snapshot.children
            var matchingIDs: [String] = []

            while let childSnap = enumerator.nextObject() as? DataSnapshot {
                guard
                    let dict = childSnap.value as? [String:Any],
                    let members = dict["members"] as? [String],
                    members.contains(userId)
                else {
                    continue
                }
                matchingIDs.append(childSnap.key)
            }

            fetchGroups(groupIds: matchingIDs)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func createGroup(name: String, userId: String) async {
        isLoading = true
        let groupId = database.child("groups").childByAutoId().key ?? UUID().uuidString
        let now = Date().timeIntervalSince1970

        let newGroup = SafetyGroup(
            id: groupId,
            name: name,
            adminId: userId,
            members: [userId],
            pendingMembers: [],
            safetyCheckInterval: 30,
            sosInterval: 5,
            lastSafetyCheck: nil,
            currentStatus: .normal,
            createdAt: now
        )

        do {
            try await database.child("groups").child(groupId).setValue(newGroup.dictionary)
            let userGroupsRef = database.child("users").child(userId).child("groups")
            let existingSnap = try await userGroupsRef.getData()
            var existing = existingSnap.value as? [String] ?? []
            existing.append(groupId)
            try await userGroupsRef.setValue(existing)
            await loadUserGroups(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Enhanced Invitation System
    func inviteUserToGroup(groupId: String, invitedUserId: String, inviterUserId: String) async {
        do {
            // Get inviter information
            let inviterSnapshot = try await database.child("users").child(inviterUserId).getData()
            guard let inviterData = inviterSnapshot.value as? [String: Any],
                  let inviterUsername = inviterData["username"] as? String,
                  let inviterPhone = inviterData["phoneNumber"] as? String else {
                errorMessage = "Could not get inviter information"
                return
            }
            
            // Get group information
            let groupSnapshot = try await database.child("groups").child(groupId).getData()
            guard let groupData = groupSnapshot.value as? [String: Any],
                  let groupName = groupData["name"] as? String else {
                errorMessage = "Could not get group information"
                return
            }
            
            // Add to pending members
            let pendingRef = database.child("groups").child(groupId).child("pendingMembers")
            let snapshot = try await pendingRef.getData()
            var pending = snapshot.value as? [String] ?? []
            if !pending.contains(invitedUserId) {
                pending.append(invitedUserId)
                try await pendingRef.setValue(pending)

                // Create enhanced invitation with inviter details
                let inviteData: [String: Any] = [
                    "id": UUID().uuidString,
                    "groupId": groupId,
                    "groupName": groupName,
                    "invitedUserId": invitedUserId,
                    "invitedByUserId": inviterUserId,
                    "invitedByUsername": inviterUsername,
                    "invitedByPhone": inviterPhone,
                    "timestamp": Date().timeIntervalSince1970
                ]
                
                try await database.child("invitations").childByAutoId().setValue(inviteData)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptGroupInvitation(groupId: String, userId: String) async {
        do {
            let pendingRef = database.child("groups").child(groupId).child("pendingMembers")
            let pendSnap = try await pendingRef.getData()
            var pending = pendSnap.value as? [String] ?? []
            pending.removeAll { $0 == userId }
            if pending.isEmpty {
                try await pendingRef.removeValue()
            } else {
                try await pendingRef.setValue(pending)
            }

            let membersRef = database.child("groups").child(groupId).child("members")
            let memSnap = try await membersRef.getData()
            var members = memSnap.value as? [String] ?? []
            if !members.contains(userId) {
                members.append(userId)
                try await membersRef.setValue(members)
            }

            let userGroupsRef = database.child("users").child(userId).child("groups")
            let ugSnap = try await userGroupsRef.getData()
            var ug = ugSnap.value as? [String] ?? []
            if !ug.contains(groupId) {
                ug.append(groupId)
                try await userGroupsRef.setValue(ug)
            }
            
            // Remove invitation
            await removeInvitation(groupId: groupId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Enhanced Member Management
    func removeMemberFromGroup(groupId: String, memberIdToRemove: String, adminId: String) async {
        do {
            // Verify admin permissions
            let groupSnapshot = try await database.child("groups").child(groupId).getData()
            guard let groupData = groupSnapshot.value as? [String: Any],
                  let currentAdminId = groupData["adminId"] as? String,
                  currentAdminId == adminId else {
                errorMessage = "Only group admin can remove members"
                return
            }
            
            // Cannot remove admin
            if memberIdToRemove == adminId {
                errorMessage = "Cannot remove group admin"
                return
            }
            
            // Remove from group members
            let membersRef = database.child("groups").child(groupId).child("members")
            let membersSnapshot = try await membersRef.getData()
            var members = membersSnapshot.value as? [String] ?? []
            members.removeAll { $0 == memberIdToRemove }
            try await membersRef.setValue(members)
            
            // Remove group from user's groups
            let userGroupsRef = database.child("users").child(memberIdToRemove).child("groups")
            let userGroupsSnapshot = try await userGroupsRef.getData()
            var userGroups = userGroupsSnapshot.value as? [String] ?? []
            userGroups.removeAll { $0 == groupId }
            try await userGroupsRef.setValue(userGroups)
            
            // Reload group members
            if let currentGroup = currentGroup, currentGroup.id == groupId {
                await loadGroupMembers(group: currentGroup)
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leaveGroup(groupId: String, userId: String) async {
        do {
            let membersRef = database.child("groups").child(groupId).child("members")
            let mSnap = try await membersRef.getData()
            var members = mSnap.value as? [String] ?? []
            members.removeAll { $0 == userId }
            try await membersRef.setValue(members)

            let ugRef = database.child("users").child(userId).child("groups")
            let ugSnap = try await ugRef.getData()
            var ug = ugSnap.value as? [String] ?? []
            ug.removeAll { $0 == groupId }
            try await ugRef.setValue(ug)

            let gSnap = try await database.child("groups").child(groupId).getData()
            if let dict = gSnap.value as? [String:Any],
               dict["adminId"] as? String == userId,
               members.isEmpty {
                try await database.child("groups").child(groupId).removeValue()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Enhanced Group Management
    func deleteGroup(groupId: String, adminId: String) async {
        do {
            // Verify admin permissions
            let groupSnapshot = try await database.child("groups").child(groupId).getData()
            guard let groupData = groupSnapshot.value as? [String: Any],
                  let currentAdminId = groupData["adminId"] as? String,
                  currentAdminId == adminId else {
                errorMessage = "Only group admin can delete the group"
                return
            }
            
            let members = groupData["members"] as? [String] ?? []
            
            // Remove group from all members' group lists
            for memberId in members {
                let userGroupsRef = database.child("users").child(memberId).child("groups")
                let userGroupsSnapshot = try await userGroupsRef.getData()
                var userGroups = userGroupsSnapshot.value as? [String] ?? []
                userGroups.removeAll { $0 == groupId }
                try await userGroupsRef.setValue(userGroups)
            }
            
            // Delete all related data
            try await database.child("groups").child(groupId).removeValue()
            
            // Delete safety checks for this group
            let safetyChecksSnapshot = try await database.child("safetyChecks").getData()
            let safetyChecksChildren = safetyChecksSnapshot.children.allObjects
            for child in safetyChecksChildren {
                if let childSnapshot = child as? DataSnapshot,
                   let checkData = childSnapshot.value as? [String: Any],
                   let checkGroupId = checkData["groupId"] as? String,
                   checkGroupId == groupId {
                    try await database.child("safetyChecks").child(childSnapshot.key).removeValue()
                }
            }
            
            // Delete SOS alerts for this group
            let sosAlertsSnapshot = try await database.child("sosAlerts").getData()
            let sosAlertsChildren = sosAlertsSnapshot.children.allObjects
            for child in sosAlertsChildren {
                if let childSnapshot = child as? DataSnapshot,
                   let alertData = childSnapshot.value as? [String: Any],
                   let alertGroupId = alertData["groupId"] as? String,
                   alertGroupId == groupId {
                    try await database.child("sosAlerts").child(childSnapshot.key).removeValue()
                }
            }
            
            // Delete invitations for this group
            let invitationsSnapshot = try await database.child("invitations").getData()
            let invitationsChildren = invitationsSnapshot.children.allObjects
            for child in invitationsChildren {
                if let childSnapshot = child as? DataSnapshot,
                   let inviteData = childSnapshot.value as? [String: Any],
                   let inviteGroupId = inviteData["groupId"] as? String,
                   inviteGroupId == groupId {
                    try await database.child("invitations").child(childSnapshot.key).removeValue()
                }
            }
            
            // Reload user groups
            await loadUserGroups(userId: adminId)
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateGroupName(groupId: String, newName: String, adminId: String) async {
        do {
            // Verify admin permissions
            let groupSnapshot = try await database.child("groups").child(groupId).getData()
            guard let groupData = groupSnapshot.value as? [String: Any],
                  let currentAdminId = groupData["adminId"] as? String,
                  currentAdminId == adminId else {
                errorMessage = "Only group admin can edit group name"
                return
            }
            
            // Update group name
            try await database.child("groups").child(groupId).child("name").setValue(newName)
            
            // Update current group if it's the one being edited
            if let currentGroup = currentGroup, currentGroup.id == groupId {
                var updatedGroup = currentGroup
                updatedGroup.name = newName
                self.currentGroup = updatedGroup
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateSafetyCheckInterval(groupId: String, newInterval: Int, adminId: String) async {
        do {
            // Verify admin permissions
            let groupSnapshot = try await database.child("groups").child(groupId).getData()
            guard let groupData = groupSnapshot.value as? [String: Any],
                  let currentAdminId = groupData["adminId"] as? String,
                  currentAdminId == adminId else {
                errorMessage = "Only group admin can edit safety check interval"
                return
            }
            
            // Validate interval (between 1 and 1440 minutes = 24 hours)
            guard newInterval >= 1 && newInterval <= 1440 else {
                errorMessage = "Safety check interval must be between 1 and 1440 minutes"
                return
            }
            
            // Update safety check interval
            try await database.child("groups").child(groupId).child("safetyCheckInterval").setValue(newInterval)
            
            // Update current group if it's the one being edited
            if let currentGroup = currentGroup, currentGroup.id == groupId {
                var updatedGroup = currentGroup
                updatedGroup.safetyCheckInterval = newInterval
                self.currentGroup = updatedGroup
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateSOSInterval(groupId: String, newInterval: Int, adminId: String) async {
        do {
            // Verify admin permissions
            let groupSnapshot = try await database.child("groups").child(groupId).getData()
            guard let groupData = groupSnapshot.value as? [String: Any],
                  let currentAdminId = groupData["adminId"] as? String,
                  currentAdminId == adminId else {
                errorMessage = "Only group admin can edit SOS interval"
                return
            }
            
            // Validate interval (between 1 and 60 minutes)
            guard newInterval >= 1 && newInterval <= 60 else {
                errorMessage = "SOS interval must be between 1 and 60 minutes"
                return
            }
            
            // Update SOS interval
            try await database.child("groups").child(groupId).child("sosInterval").setValue(newInterval)
            
            // Update current group if it's the one being edited
            if let currentGroup = currentGroup, currentGroup.id == groupId {
                var updatedGroup = currentGroup
                updatedGroup.sosInterval = newInterval
                self.currentGroup = updatedGroup
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Pending Invitations Management
    func loadPendingInvitations(groupId: String) async {
        do {
            let groupSnapshot = try await database.child("groups").child(groupId).getData()
            guard let groupData = groupSnapshot.value as? [String: Any],
                  let pendingMemberIds = groupData["pendingMembers"] as? [String] else {
                pendingInvitations = []
                return
            }
            
            var invitations: [GroupInvitation] = []
            
            // Get invitation details for each pending member
            let invitationsSnapshot = try await database.child("invitations").getData()
            let invitationsChildren = invitationsSnapshot.children.allObjects
            
            for child in invitationsChildren {
                if let childSnapshot = child as? DataSnapshot,
                   let inviteData = childSnapshot.value as? [String: Any],
                   let inviteGroupId = inviteData["groupId"] as? String,
                   let invitedUserId = inviteData["invitedUserId"] as? String,
                   inviteGroupId == groupId,
                   pendingMemberIds.contains(invitedUserId) {
                    
                    // Get invited user's username
                    let userSnapshot = try await database.child("users").child(invitedUserId).getData()
                    let userData = userSnapshot.value as? [String: Any]
                    let invitedUsername = userData?["username"] as? String ?? "Unknown"
                    
                    let invitation = GroupInvitation(
                        id: childSnapshot.key,
                        groupId: inviteGroupId,
                        groupName: inviteData["groupName"] as? String ?? "Unknown Group",
                        invitedUserId: invitedUserId,
                        invitedUsername: invitedUsername,
                        invitedByUserId: inviteData["invitedByUserId"] as? String ?? "",
                        invitedByUsername: inviteData["invitedByUsername"] as? String,
                        invitedByPhone: inviteData["invitedByPhone"] as? String,
                        timestamp: inviteData["timestamp"] as? Double ?? 0
                    )
                    
                    invitations.append(invitation)
                }
            }
            
            pendingInvitations = invitations.sorted { $0.timestamp > $1.timestamp }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func cancelInvitation(invitationId: String, groupId: String, invitedUserId: String, adminId: String) async {
        do {
            // Verify admin permissions
            let groupSnapshot = try await database.child("groups").child(groupId).getData()
            guard let groupData = groupSnapshot.value as? [String: Any],
                  let currentAdminId = groupData["adminId"] as? String,
                  currentAdminId == adminId else {
                errorMessage = "Only group admin can cancel invitations"
                return
            }
            
            // Remove from pending members
            let pendingRef = database.child("groups").child(groupId).child("pendingMembers")
            let pendingSnapshot = try await pendingRef.getData()
            var pending = pendingSnapshot.value as? [String] ?? []
            pending.removeAll { $0 == invitedUserId }
            
            if pending.isEmpty {
                try await pendingRef.removeValue()
            } else {
                try await pendingRef.setValue(pending)
            }
            
            // Remove invitation record
            try await database.child("invitations").child(invitationId).removeValue()
            
            // Reload pending invitations
            await loadPendingInvitations(groupId: groupId)
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func removeInvitation(groupId: String, userId: String) async {
        do {
            // Find and remove the invitation
            let invitationsSnapshot = try await database.child("invitations").getData()
            let invitationsChildren = invitationsSnapshot.children.allObjects
            
            for child in invitationsChildren {
                if let childSnapshot = child as? DataSnapshot,
                   let inviteData = childSnapshot.value as? [String: Any],
                   let inviteGroupId = inviteData["groupId"] as? String,
                   let invitedUserId = inviteData["invitedUserId"] as? String,
                   inviteGroupId == groupId,
                   invitedUserId == userId {
                    try await database.child("invitations").child(childSnapshot.key).removeValue()
                    break
                }
            }
        } catch {
            print("Error removing invitation: \(error)")
        }
    }
    
    /// Initiate a safety check: rate‐limit, write to `/safetyChecks`, update group status & lastSafetyCheck.
    func inititateSafetyCheck(groupId: String, initiatedBy: String) async -> Bool {
        print("🎯 Starting safety check creation...")
        print("🎯 Group ID: \(groupId)")
        print("🎯 Initiated by: \(initiatedBy)")
        
        do {
            // Rate limit check
            let gSnap = try await database.child("groups").child(groupId).getData()
            guard let d = gSnap.value as? [String:Any] else {
                print("❌ Group not found: \(groupId)")
                return false
            }
            
            print("✅ Group found in Firebase")
            
            let interval = d["safetyCheckInterval"] as? Int ?? 30
            let last = d["lastSafetyCheck"] as? Double ?? 0
            let now = Date().timeIntervalSince1970
            
            if now - last < Double(interval * 60) {
                let rem = Int((Double(interval*60) - (now - last)) / 60)
                errorMessage = "Wait \(rem) more minutes."
                print("⏰ Rate limited: \(rem) minutes remaining")
                return false
            }
            
            // ✅ NEW: Check for active SOS alerts before determining group status
            print("🔍 Checking for active SOS alerts before setting group status...")
            let hasActiveSOSAlerts = await checkForActiveSOSAlerts(groupId: groupId)
            
            // Create safety check
            let checkId = database.child("safetyChecks").childByAutoId().key ?? UUID().uuidString
            let check = SafetyCheck(
                id: checkId,
                groupId: groupId,
                initiatedBy: initiatedBy,
                timestamp: now
            )
            
            print("🎯 Creating safety check:")
            print("   - Check ID: \(checkId)")
            print("   - Group ID: \(groupId)")
            
            try await database.child("safetyChecks").child(checkId).setValue(check.dictionary)
            print("✅ Safety check written to Firebase")
            
            // ✅ ENHANCED: Set appropriate group status based on SOS alerts
            let newStatus: SafetyGroupStatus
            if hasActiveSOSAlerts {
                newStatus = .emergency
                print("🚨 Active SOS alerts found - keeping group in EMERGENCY status")
            } else {
                newStatus = .checkingStatus
                print("✅ No active SOS alerts - setting group to CHECKING status")
            }
            
            // Update group status and record timestamp
            try await database.child("groups").child(groupId).updateChildValues([
                "currentStatus": newStatus.rawValue,
                "lastSafetyCheck": now
            ])
            print("✅ Group status updated to '\(newStatus.rawValue)'")
            
            return true
            
        } catch {
            print("❌ Error creating safety check: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    // ✅ NEW HELPER FUNCTION: Check for active SOS alerts
    private func checkForActiveSOSAlerts(groupId: String) async -> Bool {
        do {
            print("🔍 Checking for active SOS alerts in group: \(groupId)")
            
            let sosSnapshot = try await database.child("sosAlerts")
                .queryOrdered(byChild: "groupId")
                .queryEqual(toValue: groupId)
                .getData()
            
            guard sosSnapshot.exists() else {
                print("🔍 No SOS alerts found for group")
                return false
            }
            
            var activeSOSCount = 0
            let sosChildren = sosSnapshot.children.allObjects
            
            for child in sosChildren {
                if let childSnapshot = child as? DataSnapshot,
                   let sosDict = childSnapshot.value as? [String: Any] {
                    
                    let sosAlertId = childSnapshot.key
                    let sosIsActive = sosDict["isActive"] as? Bool ?? false
                    
                    if sosIsActive {
                        activeSOSCount += 1
                        print("🚨 Found active SOS alert: \(sosAlertId)")
                    }
                }
            }
            
            print("🔍 Total active SOS alerts found: \(activeSOSCount)")
            return activeSOSCount > 0
            
        } catch {
            print("❌ Error checking for active SOS alerts: \(error)")
            // If we can't check, assume no active SOS alerts to avoid blocking safety checks
            return false
        }
    }
    
    func scheduleStatusReset(groupId: String, delayMinutes: Int = 60) async {
        // Only reset from .allSafe to .normal after a delay
        // This gives users time to see the "all safe" confirmation
        
        print("⏰ Scheduling status reset for group \(groupId) in \(delayMinutes) minutes")
        
        Task {
            // Wait for the specified delay
            try? await Task.sleep(nanoseconds: UInt64(delayMinutes * 60 * 1_000_000_000))
            
            do {
                // Check current status before resetting
                let snapshot = try await database.child("groups").child(groupId).getData()
                guard let dict = snapshot.value as? [String: Any],
                      let currentStatus = dict["currentStatus"] as? String,
                      currentStatus == SafetyGroupStatus.allSafe.rawValue else {
                    print("⏰ Group status changed, skipping auto-reset")
                    return
                }
                
                // Reset to normal if still showing allSafe
                try await database
                    .child("groups")
                    .child(groupId)
                    .child("currentStatus")
                    .setValue(SafetyGroupStatus.normal.rawValue)
                
                print("✅ Auto-reset group \(groupId) status to normal")
                
            } catch {
                print("❌ Error in auto status reset: \(error)")
            }
        }
    }
    
    /// Send an SOS: rate‐limit per user+group, write `/sosAlerts`, update userSOSTimes & group status.
    func sendSOSAlert(groupId: String, userId: String, location: LocationData, message: String? = nil) async -> Bool {
        do {
            // rate‐limit per user/group
            let userSOSRef = database.child("userSOSTimes").child(userId).child(groupId)
            let lastSnap = try await userSOSRef.getData()
            let last = lastSnap.value as? Double ?? 0
            let now = Date().timeIntervalSince1970
            
            let gSnap = try await database.child("groups").child(groupId).getData()
            guard let gd = gSnap.value as? [String:Any] else { return false }
            let interval = gd["sosInterval"] as? Int ?? 5
            
            if now - last < Double(interval * 60) {
                let rem = Int((Double(interval*60) - (now - last)) / 60)
                errorMessage = "Wait \(rem) more minutes for another SOS."
                return false
            }
            
            // write SOSAlert
            let alertId = database.child("sosAlerts").childByAutoId().key ?? UUID().uuidString
            let sos = SOSAlert(id: alertId, userId: userId, groupId: groupId, timestamp: now, location: location, message: message)
            try await database.child("sosAlerts").child(alertId).setValue(sos.dictionary)
            
            // update last SOS
            try await userSOSRef.setValue(now)
            
            // set group emergency
            try await database
                .child("groups")
                .child(groupId)
                .child("currentStatus")
                .setValue(SafetyGroupStatus.emergency.rawValue)
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    /// Load ALL members for a given group (not just from cache)
    func loadGroupMembers(group: SafetyGroup) async {
        do {
            var members: [User] = []
            for memberId in group.members {
                let snap = try await database.child("users").child(memberId).getData()
                if let d = snap.value as? [String:Any],
                   let json = try? JSONSerialization.data(withJSONObject: d),
                   let user = try? JSONDecoder().decode(User.self, from: json) {
                    members.append(user)
                }
            }
            groupMembers = members
        } catch {
            print("Error loading members:", error)
            errorMessage = "Failed to load group members"
        }
    }
    
    func forceReloadSafetyChecks(groupId: String) async {
        print("🔄 Force reloading safety checks for group: \(groupId)")
        
        do {
            let snapshot = try await database.child("safetyChecks").getData()
            var checks: [SafetyCheck] = []
            
            let snapshotChildren = snapshot.children.allObjects
            for child in snapshotChildren {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any],
                   let checkGroupId = dict["groupId"] as? String,
                   checkGroupId == groupId {
                    
                    let json = try JSONSerialization.data(withJSONObject: dict)
                    if let check = try? JSONDecoder().decode(SafetyCheck.self, from: json) {
                        checks.append(check)
                        print("🔄 Found safety check: \(check.id), status: \(check.status)")
                    }
                }
            }
            
            // Update the safety checks array on MainActor
            await MainActor.run {
                let sortedChecks = checks.sorted { $0.timestamp > $1.timestamp }
                self.safetyChecks = sortedChecks
                print("🔄 Force reload complete: \(checks.count) safety checks loaded")
            }
            
        } catch {
            print("❌ Error force reloading safety checks: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to reload safety checks"
            }
        }
    }
    
    func setCurrentGroup(_ group: SafetyGroup) {
        currentGroup = group
        print("🔍 Set current group to: \(group.id)")
        print("🔍 SOS alerts for this group: \(sosAlertsByGroup[group.id]?.count ?? 0)")
        objectWillChange.send()
    }
    
    func respondToSafetyCheck(checkId: String, userId: String, status: SafetyResponseStatus, location: LocationData?, message: String? = nil) async {
        do {
            print("🎯 Responding to safety check: \(checkId)")
            print("🎯 User: \(userId), Status: \(status.rawValue)")
            
            let responseTimestamp = Date().timeIntervalSince1970
            let resp = SafetyResponse(userId: userId, status: status, timestamp: responseTimestamp, location: location, message: message)
            
            // ✅ STEP 1: Write the safety check response
            try await database
                .child("safetyChecks")
                .child(checkId)
                .child("responses")
                .child(userId)
                .setValue(resp.dictionary)
            
            print("✅ Safety check response written successfully")
            
            // ✅ STEP 2: If SOS response, IMMEDIATELY create SOS alert and update group status
            if status == .sos {
                print("🚨 SOS response detected - creating SOS alert immediately")
                
                // ✅ FIX: Get the safety check data correctly
                let checkSnapshot = try await database.child("safetyChecks").child(checkId).getData()
                
                // The data structure is direct, not nested
                guard let checkData = checkSnapshot.value as? [String: Any],
                      let groupId = checkData["groupId"] as? String else {
                    print("❌ Could not get group ID from safety check")
                    print("🔍 Safety check data structure: \(checkSnapshot.value ?? "nil")")
                    
                    // ✅ FALLBACK: Try to find groupId from current group if available
                    if let currentGroupId = currentGroup?.id {
                        print("🔄 Using current group ID as fallback: \(currentGroupId)")
                        await createSOSFromSafetyResponse(
                            groupId: currentGroupId,
                            userId: userId,
                            checkId: checkId,
                            responseTimestamp: responseTimestamp,
                            location: location,
                            message: message
                        )
                    }
                    return
                }
                
                print("✅ Found group ID: \(groupId)")
                
                await createSOSFromSafetyResponse(
                    groupId: groupId,
                    userId: userId,
                    checkId: checkId,
                    responseTimestamp: responseTimestamp,
                    location: location,
                    message: message
                )
                
            } else if status == .safe {
                // If user marked themselves as SAFE, check for SOS resolution
                await checkAndResolveUserSOSAlerts(userId: userId, checkId: checkId)
                // Then check completion
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await checkSafetyCheckCompletion(checkId: checkId)
            } else {
                // For any other response, check completion
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await checkSafetyCheckCompletion(checkId: checkId)
            }
            
        } catch {
            print("❌ Error responding to safety check: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func forceReloadSOSAlerts(groupId: String) async {
        do {
            print("🔄 Force reloading SOS alerts for group: \(groupId)")
            
            let sosSnapshot = try await database.child("sosAlerts")
                .queryOrdered(byChild: "groupId")
                .queryEqual(toValue: groupId)
                .getData()
            
            var alerts: [SOSAlert] = []
            
            let sosChildren = sosSnapshot.children.allObjects
            for child in sosChildren {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any] {
                    
                    do {
                        let json = try JSONSerialization.data(withJSONObject: dict)
                        let alert = try JSONDecoder().decode(SOSAlert.self, from: json)
                        
                        if alert.isActive {
                            alerts.append(alert)
                            print("🔄 Found active SOS alert: \(alert.id)")
                        }
                    } catch {
                        print("❌ Error decoding SOS alert: \(error)")
                    }
                }
            }
            
            // Update on main thread
            await MainActor.run {
                self.sosAlertsByGroup[groupId] = alerts
                print("✅ Force updated sosAlertsByGroup for group \(groupId): \(alerts.count) alerts")
                
                // Force UI update
                self.objectWillChange.send()
            }
            
        } catch {
            print("❌ Error force reloading SOS alerts: \(error)")
        }
    }
    
    // MARK: - Private listeners
    
    private func fetchGroups(groupIds: [String]) {
        // cleanup old listeners
        for (gid, handle) in groupListeners {
            database.child("groups").child(gid).removeObserver(withHandle: handle)
        }
        groupListeners.removeAll()
        groups.removeAll()

        guard !groupIds.isEmpty else {
            isLoading = false
            return
        }

        let invalidChars = CharacterSet(charactersIn: ".#$[]")
        for rawId in groupIds {
            print("Check group ID: '\(rawId)'")
            let id = rawId.trimmingCharacters(in: .whitespacesAndNewlines)
            // skip if empty or contains any illegal Firebase path characters
            guard !id.isEmpty,
                  id.rangeOfCharacter(from: invalidChars) == nil
            else {
                print("Skipping invalid group ID: '\(rawId)'")
                continue
            }

            let ref = database.child("groups").child(id)
            let handle = ref.observe(.value) { [weak self] snapshot in
                guard
                    let self = self,
                    let dict = snapshot.value as? [String:Any]
                else { return }

                do {
                    let data = try JSONSerialization.data(withJSONObject: dict)
                    let group = try JSONDecoder().decode(SafetyGroup.self, from: data)

                    Task { @MainActor in
                        if let idx = self.groups.firstIndex(where: { $0.id == group.id }) {
                            self.groups[idx] = group
                        } else {
                            self.groups.append(group)
                        }
                        self.isLoading = false

                        self.listenForSafetyChecks(groupId: id)
                        self.listenForSOSAlerts(groupId: id)
                    }
                } catch {
                    print("Error decoding group \(id):", error)
                    Task { @MainActor in
                        self.errorMessage = "Failed to load group data"
                    }
                }
            }

            groupListeners[id] = handle
        }
    }

    private func listenForSafetyChecks(groupId: String) {
        guard safetyCheckListeners[groupId] == nil else { return }
        
        print("🔍 Setting up Firebase listener for safety checks")
        print("🔍 Group ID: \(groupId)")
        
        // Use the correct Firebase listener approach
        let handle = database
            .child("safetyChecks")
            .observe(.value) { [weak self] snapshot in
                guard let self = self else { return }
                var checks: [SafetyCheck] = []
                
                print("🔍 Firebase listener triggered: \(snapshot.childrenCount) total safety checks")
                
                // Convert children to array to avoid iterator issues
                let snapshotChildren = snapshot.children.allObjects
                for child in snapshotChildren {
                    if let childSnapshot = child as? DataSnapshot,
                       let dict = childSnapshot.value as? [String:Any] {
                        let checkGroupId = dict["groupId"] as? String ?? ""
                        
                        // Only process checks for this specific group
                        if checkGroupId == groupId {
                            print("🔍 Processing safety check for our group: \(childSnapshot.key)")
                            
                            // Create SafetyCheck manually to handle missing responses field
                            if let id = dict["id"] as? String,
                               let groupId = dict["groupId"] as? String,
                               let initiatedBy = dict["initiatedBy"] as? String,
                               let timestamp = dict["timestamp"] as? Double {
                                
                                var check = SafetyCheck(
                                    id: id,
                                    groupId: groupId,
                                    initiatedBy: initiatedBy,
                                    timestamp: timestamp
                                )
                                
                                // Handle status
                                if let statusString = dict["status"] as? String,
                                   let status = SafetyCheckStatus(rawValue: statusString) {
                                    check.status = status
                                }
                                
                                // Handle responses (may not exist initially)
                                if let responsesDict = dict["responses"] as? [String: [String: Any]] {
                                    var responses: [String: SafetyResponse] = [:]
                                    for (userId, responseDict) in responsesDict {
                                        if let responseUserId = responseDict["userId"] as? String,
                                           let responseStatusString = responseDict["status"] as? String,
                                           let responseStatus = SafetyResponseStatus(rawValue: responseStatusString),
                                           let responseTimestamp = responseDict["timestamp"] as? Double {
                                            
                                            var location: LocationData?
                                            if let locationDict = responseDict["location"] as? [String: Any],
                                               let lat = locationDict["latitude"] as? Double,
                                               let lng = locationDict["longitude"] as? Double {
                                                location = LocationData(latitude: lat, longitude: lng, address: locationDict["address"] as? String)
                                            }
                                            
                                            let response = SafetyResponse(
                                                userId: responseUserId,
                                                status: responseStatus,
                                                timestamp: responseTimestamp,
                                                location: location,
                                                message: responseDict["message"] as? String
                                            )
                                            responses[userId] = response
                                        }
                                    }
                                    check.responses = responses
                                }
                                
                                checks.append(check)
                                print("✅ Successfully decoded safety check: \(check.id), status: \(check.status)")
                            }
                        }
                    }
                }
                
                // Update on main thread
                Task { @MainActor in
                    let sortedChecks = checks.sorted { $0.timestamp > $1.timestamp }
                    self.safetyChecks = sortedChecks
                    
                    print("🎯 LISTENER UPDATED safetyChecks: \(sortedChecks.count) total for group \(groupId)")
                    if let recent = sortedChecks.first {
                        print("🎯 Most recent check: \(recent.id), status: \(recent.status)")
                    }
                }
            }
        
        safetyCheckListeners[groupId] = handle
    }
    
    private func listenForSOSAlerts(groupId: String) {
        guard sosAlertListeners[groupId] == nil else {
            print("🔍 SOS listener already exists for group: \(groupId)")
            return
        }
        
        print("🚨 Setting up SOS alerts listener for group: \(groupId)")
        
        let handle = database
            .child("sosAlerts")
            .queryOrdered(byChild: "groupId")
            .queryEqual(toValue: groupId)
            .observe(.value) { [weak self] snapshot in
                guard let self = self else { return }
                var alerts: [SOSAlert] = []
                
                print("🚨 SOS listener triggered for group \(groupId)")
                print("🚨 Found \(snapshot.childrenCount) total SOS records")
                
                let snapshotChildren = snapshot.children.allObjects
                for child in snapshotChildren {
                    if let childSnapshot = child as? DataSnapshot,
                       let dict = childSnapshot.value as? [String:Any] {
                        
                        print("🚨 Processing SOS alert: \(childSnapshot.key)")
                        print("🚨 SOS data: \(dict)")
                        
                        do {
                            let json = try JSONSerialization.data(withJSONObject: dict)
                            let alert = try JSONDecoder().decode(SOSAlert.self, from: json)
                            
                            print("🚨 Decoded SOS alert:")
                            print("   - ID: \(alert.id)")
                            print("   - User: \(alert.userId)")
                            print("   - Group: \(alert.groupId)")
                            print("   - Active: \(alert.isActive)")
                            print("   - Timestamp: \(alert.timestamp)")
                            
                            if alert.isActive {
                                alerts.append(alert)
                                print("✅ Added active SOS alert: \(alert.id)")
                            } else {
                                print("❌ Skipped inactive SOS alert: \(alert.id)")
                            }
                        } catch {
                            print("❌ Error decoding SOS alert \(childSnapshot.key): \(error)")
                        }
                    }
                }
                
                print("🚨 Final active SOS alerts count: \(alerts.count)")
                
                // 🔥 FIX: Actually update the sosAlertsByGroup dictionary on MainActor
                Task { @MainActor in
                    self.sosAlertsByGroup[groupId] = alerts
                    print("✅ Updated sosAlertsByGroup for group \(groupId): \(alerts.count) alerts")
                    
                    // Force UI update
                    self.objectWillChange.send()
                    
                    // Debug: Print current state
                    print("🎯 Current sosAlertsByGroup state:")
                    for (gId, gAlerts) in self.sosAlertsByGroup {
                        print("   Group \(gId): \(gAlerts.count) alerts")
                    }
                    
                    if let currentGroup = self.currentGroup, currentGroup.id == groupId {
                        print("🎯 Current group matches - activeSOSAlerts should show \(alerts.count) alerts")
                    }
                }
            }
        
        sosAlertListeners[groupId] = handle
        print("✅ SOS listener registered for group: \(groupId)")
    }
    
    private func checkSafetyCheckCompletion(checkId: String) async {
        do {
            print("🔍 Checking completion for safety check: \(checkId)")
            
            let specificCheckRef = database.child("safetyChecks").child(checkId)
            let snap = try await specificCheckRef.getData()
            
            guard snap.exists() else {
                print("❌ Safety check \(checkId) does not exist")
                return
            }
            
            guard let responseData = snap.value as? [String: Any] else {
                print("❌ Could not parse safety check data")
                return
            }
            
            // ✅ SMART DETECTION: Check if we got specific data or all data
            var safetyCheckData: [String: Any]
            
            if responseData.keys.contains("groupId") {
                // ✅ CASE 1: We got the specific safety check directly
                print("✅ Received SPECIFIC safety check data")
                safetyCheckData = responseData
                
            } else if responseData.keys.contains(checkId) {
                // ✅ CASE 2: We got all safety checks, extract the specific one
                print("🔍 Received ALL safety checks data, extracting specific one")
                guard let specificData = responseData[checkId] as? [String: Any] else {
                    print("❌ Could not extract specific safety check: \(checkId)")
                    print("🔍 Available safety checks: \(Array(responseData.keys))")
                    return
                }
                safetyCheckData = specificData
                
            } else {
                // ❌ CASE 3: Unexpected data structure
                print("❌ Unexpected data structure received")
                print("🔍 Response keys: \(Array(responseData.keys))")
                print("🔍 Looking for either 'groupId' (specific) or '\(checkId)' (all data)")
                return
            }
            
            
            // ✅ USE YOUR SAFETYCHECK MODEL
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: safetyCheckData)
                let safetyCheck = try JSONDecoder().decode(SafetyCheck.self, from: jsonData)
                
                print("✅ Successfully decoded SafetyCheck model:")
                print("   - ID: \(safetyCheck.id)")
                print("   - GroupId: \(safetyCheck.groupId)")
                print("   - Status: \(safetyCheck.status)")
                print("   - Responses: \(safetyCheck.responses.count)")
                
                // Now we can work with the clean model!
                await processCompletedSafetyCheck(safetyCheck)
                
            } catch {
                print("❌ Error decoding SafetyCheck model: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, _):
                        print("❌ Missing key: \(key)")
                    case .typeMismatch(let type, let context):
                        print("❌ Type mismatch for \(type) at \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("❌ Value not found for \(type) at \(context.codingPath)")
                    default:
                        print("❌ Other decoding error: \(decodingError)")
                    }
                }
                return
            }
            
        } catch {
            print("❌ Error checking safety check completion: \(error)")
            errorMessage = "Failed to complete safety check: \(error.localizedDescription)"
        }
    }
    
    private func processCompletedSafetyCheck(_ safetyCheck: SafetyCheck) async {
        do {
            print("🔍 Processing safety check: \(safetyCheck.id)")
            
            // Get group data
            let gSnap = try await database.child("groups").child(safetyCheck.groupId).getData()
            guard gSnap.exists(),
                  let gDict = gSnap.value as? [String: Any],
                  let members = gDict["members"] as? [String] else {
                print("❌ Could not get group members for group: \(safetyCheck.groupId)")
                return
            }
            
            print("🔍 Group members: \(members)")
            print("🔍 Group member count: \(members.count)")
            print("🔍 Current responses: \(safetyCheck.responses.count)")
            
            // Show response details using the model
            let respondedMembers = Array(safetyCheck.responses.keys)
            let missingMembers = members.filter { !respondedMembers.contains($0) }
            
            print("✅ Members who responded: \(respondedMembers)")
            print("⏳ Members still pending: \(missingMembers)")
            
            // Check each response using the model
            var hasSOS = false
            for (userId, response) in safetyCheck.responses {
                print("📝 User \(userId) responded: \(response.status.rawValue)")
                if response.status == .sos {
                    hasSOS = true
                    print("🚨 SOS response detected from user: \(userId)")
                }
            }
            
            // ✅ Resolve SOS alerts for SAFE responses
            await resolveSOSAlertsForSafeResponses(
                groupId: safetyCheck.groupId,
                responses: safetyCheck.responses, // Pass the clean model responses
                safetyCheckTimestamp: safetyCheck.timestamp
            )
            
            // Check if all members have responded
            let allResponded = members.allSatisfy { memberId in
                safetyCheck.responses[memberId] != nil
            }
            
            print("🔍 All responded check: \(allResponded)")
            
            if allResponded {
                print("✅ All members have responded - processing final status")
                
                // Determine final statuses using model
                let finalCheckStatus: SafetyCheckStatus = hasSOS ? .emergency : .allSafe
                let finalGroupStatus: SafetyGroupStatus = hasSOS ? .emergency : .allSafe
                
                print("🎯 Final statuses determined:")
                print("   - Check status: \(finalCheckStatus.rawValue)")
                print("   - Group status: \(finalGroupStatus.rawValue)")
                print("   - SOS detected: \(hasSOS)")
                
                // Update safety check status
                try await database
                    .child("safetyChecks")
                    .child(safetyCheck.id)
                    .child("status")
                    .setValue(finalCheckStatus.rawValue)
                
                print("✅ Updated safety check status to: \(finalCheckStatus.rawValue)")
                
                // Update group status (only if not already emergency from SOS)
                if !hasSOS {
                    try await database
                        .child("groups")
                        .child(safetyCheck.groupId)
                        .child("currentStatus")
                        .setValue(finalGroupStatus.rawValue)
                    
                    print("✅ Updated group status to: \(finalGroupStatus.rawValue)")
                    
                    // Schedule auto-reset for allSafe status
                    if finalGroupStatus == .allSafe {
                        await scheduleStatusReset(groupId: safetyCheck.groupId, delayMinutes: 60)
                    }
                }
                
            } else {
                print("⏳ Still waiting for responses from \(members.count - safetyCheck.responses.count) members")
                print("⏳ Missing responses from: \(missingMembers)")
                
                // Keep status as pending
                try await database
                    .child("safetyChecks")
                    .child(safetyCheck.id)
                    .child("status")
                    .setValue(SafetyCheckStatus.pending.rawValue)
                
                await forceReloadSafetyChecks(groupId: safetyCheck.groupId);
                
                print("⏳ Kept safety check status as pending")
            }
            
        } catch {
            print("❌ Error processing safety check: \(error)")
            errorMessage = "Failed to process safety check: \(error.localizedDescription)"
        }
    }

    // ✅ ALSO UPDATE resolveSOSAlertsForSafeResponses TO USE MODELS
    private func resolveSOSAlertsForSafeResponses(
        groupId: String,
        responses: [String: SafetyResponse], // Use the model type
        safetyCheckTimestamp: Double
    ) async {
        
        print("🔍 Checking for SOS alerts to resolve based on SAFE responses...")
        
        do {
            // Get all active SOS alerts for this group
            let sosSnapshot = try await database.child("sosAlerts")
                .queryOrdered(byChild: "groupId")
                .queryEqual(toValue: groupId)
                .getData()
            
            guard sosSnapshot.exists() else {
                print("🔍 No SOS alerts found for group")
                return
            }
            
            var alertsToResolve: [String] = []
            var resolvedUsers: [String] = []
            
            // Check each SOS alert
            let sosChildren = sosSnapshot.children.allObjects
            for child in sosChildren {
                if let childSnapshot = child as? DataSnapshot,
                   let sosDict = childSnapshot.value as? [String: Any] {
                    
                    let sosAlertId = childSnapshot.key
                    let sosUserId = sosDict["userId"] as? String ?? ""
                    let sosTimestamp = sosDict["timestamp"] as? Double ?? 0
                    let sosIsActive = sosDict["isActive"] as? Bool ?? false
                    
                    print("🔍 Checking SOS alert: \(sosAlertId)")
                    print("   - User: \(sosUserId)")
                    print("   - Timestamp: \(sosTimestamp)")
                    print("   - Active: \(sosIsActive)")
                    
                    // Check if this user has an active SOS alert that's older than the safety check
                    if sosIsActive &&
                       sosTimestamp < safetyCheckTimestamp &&
                       !sosUserId.isEmpty {
                        
                        // ✅ Use the model to check if user marked themselves as SAFE
                        if let userResponse = responses[sosUserId],
                           userResponse.status == .safe {
                            
                            print("✅ User \(sosUserId) marked SAFE after SOS - resolving alert \(sosAlertId)")
                            alertsToResolve.append(sosAlertId)
                            resolvedUsers.append(sosUserId)
                        }
                    }
                }
            }
            
            // Resolve the identified SOS alerts
            for alertId in alertsToResolve {
                await resolveSOSAlert(alertId: alertId)
            }
            
            if !resolvedUsers.isEmpty {
                print("✅ Resolved SOS alerts for users: \(resolvedUsers)")
            } else {
                print("🔍 No SOS alerts needed resolution")
            }
            
        } catch {
            print("❌ Error resolving SOS alerts: \(error)")
        }
    }
    
    private func checkAndResolveUserSOSAlerts(userId: String, checkId: String) async {
        do {
            print("🔍 Checking if user \(userId) has active SOS alerts to resolve...")
            
            // Get the safety check timestamp - WITH BETTER ERROR HANDLING
            let checkSnapshot = try await database.child("safetyChecks").child(checkId).getData()
            
            var safetyCheckTimestamp: Double = Date().timeIntervalSince1970
            
            if let checkData = checkSnapshot.value as? [String: Any] {
                if let timestamp = checkData["timestamp"] as? Double {
                    safetyCheckTimestamp = timestamp
                    print("🔍 Using safety check timestamp: \(safetyCheckTimestamp)")
                } else {
                    print("⚠️ No timestamp in safety check, using current time")
                }
            } else {
                print("⚠️ Could not parse safety check data, using current time")
            }
            
            // SIMPLIFIED: Get ALL SOS alerts and filter manually (avoids index issues)
            print("🔍 Getting all SOS alerts to filter manually...")
            let sosSnapshot = try await database.child("sosAlerts").getData()
            
            guard sosSnapshot.exists() else {
                print("🔍 No SOS alerts found at all")
                return
            }
            
            var resolvedCount = 0
            let sosChildren = sosSnapshot.children.allObjects
            
            for child in sosChildren {
                if let childSnapshot = child as? DataSnapshot,
                   let sosDict = childSnapshot.value as? [String: Any] {
                    
                    let sosUserId = sosDict["userId"] as? String ?? ""
                    let sosTimestamp = sosDict["timestamp"] as? Double ?? 0
                    let sosIsActive = sosDict["isActive"] as? Bool ?? false
                    
                    print("🔍 Checking SOS alert: \(childSnapshot.key)")
                    print("   - User: \(sosUserId)")
                    print("   - Active: \(sosIsActive)")
                    print("   - Timestamp: \(sosTimestamp)")
                    
                    // Check if this SOS is for our user and should be resolved
                    if sosUserId == userId && sosIsActive && sosTimestamp < safetyCheckTimestamp {
                        print("✅ Resolving SOS alert: \(childSnapshot.key)")
                        await resolveSOSAlert(alertId: childSnapshot.key)
                        resolvedCount += 1
                    }
                }
            }
            
            if resolvedCount > 0 {
                print("✅ Resolved \(resolvedCount) SOS alert(s) for user \(userId)")
            } else {
                print("🔍 No SOS alerts needed resolution for user \(userId)")
            }
            
        } catch {
            print("❌ Error checking user SOS alerts: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            // Don't throw - continue with safety check completion
        }
    }

    private func createSOSFromSafetyResponse(
        groupId: String,
        userId: String,
        checkId: String,
        responseTimestamp: Double,
        location: LocationData?,
        message: String?
    ) async {
        do {
            print("🚨 Creating SOS alert for group: \(groupId)")
            
            // ✅ IMMEDIATELY update group status to emergency
            try await database
                .child("groups")
                .child(groupId)
                .child("currentStatus")
                .setValue(SafetyGroupStatus.emergency.rawValue)
            
            print("✅ Group status IMMEDIATELY updated to EMERGENCY")
            
            // ✅ Create the SOS alert with proper data
            let alertId = database.child("sosAlerts").childByAutoId().key ?? UUID().uuidString
            
            let alertLocation = location ?? LocationData(latitude: 0, longitude: 0, address: "Safety check response location")
            
            let sosAlert = SOSAlert(
                id: alertId,
                userId: userId,
                groupId: groupId,
                timestamp: responseTimestamp,
                location: alertLocation,
                message: message
            )
            
            // ✅ Write SOS alert with metadata linking to safety check
            var sosData = sosAlert.dictionary
            sosData["originatedFromSafetyCheck"] = checkId
            sosData["originatedFromSafetyCheckTimestamp"] = responseTimestamp
            sosData["createdFromSafetyCheckResponse"] = true
            
            try await database.child("sosAlerts").child(alertId).setValue(sosData)
            
            print("✅ SOS alert created: \(alertId)")
            print("✅ SOS alert data: \(sosData)")
            
            // ✅ FORCE immediate reload of SOS alerts for this group
            print("🔄 Force reloading SOS alerts for immediate UI update")
            await forceReloadSOSAlerts(groupId: groupId)
            
            // ✅ Small delay then check completion
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await checkSafetyCheckCompletion(checkId: checkId)
            
        } catch {
            print("❌ Error creating SOS from safety response: \(error)")
            errorMessage = "Failed to create SOS alert: \(error.localizedDescription)"
        }
    }
        
    private func resolveSOSAlertsForSafeResponses(
        groupId: String,
        responses: [String: Any],
        safetyCheckTimestamp: Double
    ) async {
        
        print("🔍 Checking for SOS alerts to resolve based on SAFE responses...")
        
        do {
            // Get all active SOS alerts for this group
            let sosSnapshot = try await database.child("sosAlerts")
                .queryOrdered(byChild: "groupId")
                .queryEqual(toValue: groupId)
                .getData()
            
            guard sosSnapshot.exists() else {
                print("🔍 No SOS alerts found for group")
                return
            }
            
            var alertsToResolve: [String] = []
            var resolvedUsers: [String] = []
            
            // Check each SOS alert
            let sosChildren = sosSnapshot.children.allObjects
            for child in sosChildren {
                if let childSnapshot = child as? DataSnapshot,
                   let sosDict = childSnapshot.value as? [String: Any] {
                    
                    let sosAlertId = childSnapshot.key
                    let sosUserId = sosDict["userId"] as? String ?? ""
                    let sosTimestamp = sosDict["timestamp"] as? Double ?? 0
                    let sosIsActive = sosDict["isActive"] as? Bool ?? false
                    
                    print("🔍 Checking SOS alert: \(sosAlertId)")
                    print("   - User: \(sosUserId)")
                    print("   - Timestamp: \(sosTimestamp)")
                    print("   - Active: \(sosIsActive)")
                    print("   - Safety check timestamp: \(safetyCheckTimestamp)")
                    
                    // Check if this user has an active SOS alert that's older than the safety check
                    if sosIsActive &&
                       sosTimestamp < safetyCheckTimestamp &&
                       !sosUserId.isEmpty {
                        
                        // Check if this user marked themselves as SAFE in the safety check
                        if let userResponse = responses[sosUserId] as? [String: Any],
                           let responseStatus = userResponse["status"] as? String,
                           responseStatus == SafetyResponseStatus.safe.rawValue {
                            
                            print("✅ User \(sosUserId) marked SAFE after SOS - resolving alert \(sosAlertId)")
                            alertsToResolve.append(sosAlertId)
                            resolvedUsers.append(sosUserId)
                        }
                    }
                }
            }
            
            // Resolve the identified SOS alerts
            for alertId in alertsToResolve {
                await resolveSOSAlert(alertId: alertId)
            }
            
            if !resolvedUsers.isEmpty {
                print("✅ Resolved SOS alerts for users: \(resolvedUsers)")
            } else {
                print("🔍 No SOS alerts needed resolution")
            }
            
        } catch {
            print("❌ Error resolving SOS alerts: \(error)")
        }
    }

    /// Resolve/deactivate a specific SOS alert
    private func resolveSOSAlert(alertId: String) async {
        do {
            print("🔄 Resolving SOS alert: \(alertId)")
            
            // Mark as inactive
            try await database
                .child("sosAlerts")
                .child(alertId)
                .child("isActive")
                .setValue(false)
            
            // Add resolution timestamp and reason
            let resolutionData: [String: Any] = [
                "resolvedAt": Date().timeIntervalSince1970,
                "resolvedReason": "User marked safe in subsequent safety check",
                "isActive": false
            ]
            
            try await database
                .child("sosAlerts")
                .child(alertId)
                .updateChildValues(resolutionData)
            
            print("✅ SOS alert \(alertId) marked as resolved")
            
        } catch {
            print("❌ Error resolving SOS alert \(alertId): \(error)")
        }
    }

    
    private func removeAllListeners() {
        for (gid, handle) in groupListeners {
            database.child("groups").child(gid).removeObserver(withHandle: handle)
        }
        groupListeners.removeAll()
        
        for (gid, handle) in safetyCheckListeners {
            database.child("safetyChecks").queryOrdered(byChild: "groupId").queryEqual(toValue: gid).removeObserver(withHandle: handle)
        }
        safetyCheckListeners.removeAll()
        
        for (gid, handle) in sosAlertListeners {
            database.child("sosAlerts").queryOrdered(byChild: "groupId").queryEqual(toValue: gid).removeObserver(withHandle: handle)
        }
        sosAlertListeners.removeAll()
        
        if let handle = pendingInvitationsListener {
            database.removeObserver(withHandle: handle)
            pendingInvitationsListener = nil
        }
    }
}
