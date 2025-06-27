//
//  InvitationsViewModel.swift
//  SOSync
//
//  Created by Islam Saadi on 23/06/2025.
//

import Foundation
import FirebaseDatabase

@MainActor
class InvitationsViewModel: ObservableObject {
    @Published var pendingInvitations: [GroupInvitation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let database = Database.database().reference()
    private var invitationListeners: [String: DatabaseHandle] = [:]
    private var invitationsListener: DatabaseHandle?
    
    init(userId: String) {
        // Kick off an initial load immediately on init
        Task { await loadPendingInvitations(for: userId) }
        setupRealtimeListener(for: userId)
    }
    
    deinit {
        // Clean up listeners
        for (_, handle) in invitationListeners {
            database.removeObserver(withHandle: handle)
        }
        
        if let listener = invitationsListener {
            database.child("invitations").removeObserver(withHandle: listener)
        }
    }
    
    func loadPendingInvitations(for userId: String) async {
        isLoading = true
        pendingInvitations.removeAll()

        do {
            // Enhanced: Load invitations with complete inviter information
            let invitationsSnapshot = try await database.child("invitations").getData()
            var invitations: [GroupInvitation] = []
            
            let enumerator = invitationsSnapshot.children
            while let child = enumerator.nextObject() as? DataSnapshot {
                guard
                    let inviteDict = child.value as? [String: Any],
                    let invitedUserId = inviteDict["invitedUserId"] as? String,
                    invitedUserId == userId
                else {
                    continue
                }

                let invitationId = child.key
                let groupId = inviteDict["groupId"] as? String ?? ""
                let groupName = inviteDict["groupName"] as? String ?? "Unknown Group"
                let invitedByUserId = inviteDict["invitedByUserId"] as? String ?? ""
                let invitedByUsername = inviteDict["invitedByUsername"] as? String
                let invitedByPhone = inviteDict["invitedByPhone"] as? String
                let timestamp = inviteDict["timestamp"] as? Double ?? Date().timeIntervalSince1970

                // Get invited user's username (current user)
                let invitedUsername = await fetchUsername(for: userId) ?? "You"

                invitations.append(
                    GroupInvitation(
                        id: invitationId,
                        groupId: groupId,
                        groupName: groupName,
                        invitedUserId: invitedUserId,
                        invitedUsername: invitedUsername,
                        invitedByUserId: invitedByUserId,
                        invitedByUsername: invitedByUsername,
                        invitedByPhone: invitedByPhone,
                        timestamp: timestamp
                    )
                )
            }

            pendingInvitations = invitations.sorted { $0.timestamp > $1.timestamp }
            isLoading = false
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("Error loading pending invitations: \(error)")
        }
    }
    
    private func setupRealtimeListener(for userId: String) {
        // Set up real-time listener for invitations
        invitationsListener = database.child("invitations").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            Task { @MainActor in
                var invitations: [GroupInvitation] = []
                
                let enumerator = snapshot.children
                while let child = enumerator.nextObject() as? DataSnapshot {
                    guard
                        let inviteDict = child.value as? [String: Any],
                        let invitedUserId = inviteDict["invitedUserId"] as? String,
                        invitedUserId == userId
                    else {
                        continue
                    }

                    let invitationId = child.key
                    let groupId = inviteDict["groupId"] as? String ?? ""
                    let groupName = inviteDict["groupName"] as? String ?? "Unknown Group"
                    let invitedByUserId = inviteDict["invitedByUserId"] as? String ?? ""
                    let invitedByUsername = inviteDict["invitedByUsername"] as? String
                    let invitedByPhone = inviteDict["invitedByPhone"] as? String
                    let timestamp = inviteDict["timestamp"] as? Double ?? Date().timeIntervalSince1970

                    // Get invited user's username (current user)
                    let invitedUsername = await self.fetchUsername(for: userId) ?? "You"

                    invitations.append(
                        GroupInvitation(
                            id: invitationId,
                            groupId: groupId,
                            groupName: groupName,
                            invitedUserId: invitedUserId,
                            invitedUsername: invitedUsername,
                            invitedByUserId: invitedByUserId,
                            invitedByUsername: invitedByUsername,
                            invitedByPhone: invitedByPhone,
                            timestamp: timestamp
                        )
                    )
                }

                self.pendingInvitations = invitations.sorted { $0.timestamp > $1.timestamp }
            }
        }
    }
    
    func acceptInvitation(_ invitation: GroupInvitation, userId: String) async {
        do {
            print("🔍 ACCEPTING INVITATION:")
            print("🔍 Group ID: \(invitation.groupId)")
            print("🔍 User ID: \(userId)")
            
            let groupRef = database.child("groups").child(invitation.groupId)
            
            // STEP 1: Get current group data
            let groupSnapshot = try await groupRef.getData()
            guard let groupData = groupSnapshot.value as? [String: Any] else {
                print("❌ Could not get group data")
                errorMessage = "Could not access group data"
                return
            }
            
            print("🔍 Current group data: \(groupData)")
            
            // STEP 2: Update pendingMembers
            var pendingMembers = groupData["pendingMembers"] as? [String] ?? []
            print("🔍 Before - Pending members: \(pendingMembers)")
            
            pendingMembers.removeAll { $0 == userId }
            print("🔍 After - Pending members: \(pendingMembers)")
            
            // Update pendingMembers in Firebase
            if pendingMembers.isEmpty {
                try await groupRef.child("pendingMembers").removeValue()
                print("✅ Removed pendingMembers field (was empty)")
            } else {
                try await groupRef.child("pendingMembers").setValue(pendingMembers)
                print("✅ Updated pendingMembers in Firebase")
            }
            
            // STEP 3: Update members
            var members = groupData["members"] as? [String] ?? []
            print("🔍 Before - Members: \(members)")
            
            if !members.contains(userId) {
                members.append(userId)
                print("🔍 Added user to members: \(userId)")
                
                try await groupRef.child("members").setValue(members)
                print("✅ Updated members in Firebase")
            } else {
                print("🔍 User already in members")
            }
            
            print("🔍 Final members: \(members)")
            
            // STEP 4: Add group to user's groups
            let userGroupsRef = database.child("users").child(userId).child("groups")
            let userGroupsSnapshot = try await userGroupsRef.getData()
            var userGroups = userGroupsSnapshot.value as? [String] ?? []
            
            print("🔍 User's current groups: \(userGroups)")
            
            if !userGroups.contains(invitation.groupId) {
                userGroups.append(invitation.groupId)
                try await userGroupsRef.setValue(userGroups)
                print("✅ Added group to user's groups: \(invitation.groupId)")
            } else {
                print("🔍 Group already in user's groups")
            }
            
            // STEP 5: Remove invitation
            try await database.child("invitations").child(invitation.id).removeValue()
            print("✅ Removed invitation: \(invitation.id)")
            
            // STEP 6: Remove from local list
            pendingInvitations.removeAll { $0.id == invitation.id }
            print("✅ Removed from local pending invitations")
            
            print("🎉 INVITATION ACCEPTANCE COMPLETED SUCCESSFULLY!")
            
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error accepting invitation: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }
    
    func declineInvitation(_ invitation: GroupInvitation, userId: String) async {
        do {
            // Remove from pendingMembers only
            let pendingRef = database.child("groups").child(invitation.groupId).child("pendingMembers")
            let pendingSnapshot = try await pendingRef.getData()
            var pendingMembers = pendingSnapshot.value as? [String] ?? []
            pendingMembers.removeAll { $0 == userId }
            
            if pendingMembers.isEmpty {
                try await pendingRef.removeValue()
            } else {
                try await pendingRef.setValue(pendingMembers)
            }
            
            // Remove invitation
            try await database.child("invitations").child(invitation.id).removeValue()
            
            // Remove from local list
            pendingInvitations.removeAll { $0.id == invitation.id }
            
        } catch {
            errorMessage = error.localizedDescription
            print("Error declining invitation: \(error)")
        }
    }
    
    func refreshInvitations(for userId: String) async {
        await loadPendingInvitations(for: userId)
    }
    
    private func fetchUsername(for userId: String) async -> String? {
        do {
            let snapshot = try await database.child("users").child(userId).child("username").getData()
            return snapshot.value as? String
        } catch {
            print("Error fetching username for \(userId): \(error)")
            return nil
        }
    }
    
    private func fetchUserInfo(for userId: String) async -> (username: String?, phone: String?) {
        do {
            let snapshot = try await database.child("users").child(userId).getData()
            guard let userData = snapshot.value as? [String: Any] else {
                return (nil, nil)
            }
            
            let username = userData["username"] as? String
            let phone = userData["phoneNumber"] as? String
            return (username, phone)
            
        } catch {
            print("Error fetching user info for \(userId): \(error)")
            return (nil, nil)
        }
    }
}
