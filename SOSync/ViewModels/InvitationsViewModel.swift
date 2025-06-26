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
    
    init(userId: String) {
        // Kick off an initial load immediately on init
        Task { await loadPendingInvitations(for: userId) }
    }
    
    deinit {
        // Clean up listeners
        for (_, handle) in invitationListeners {
            database.removeObserver(withHandle: handle)
        }
    }
    
    func loadPendingInvitations(for userId: String) async {
        isLoading = true
        pendingInvitations.removeAll()

        let groupsRef = database.child("groups")
        groupsRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }

            Task { @MainActor in
                var invitations: [GroupInvitation] = []

                // Manually walk the snapshot.children enumerator to avoid `makeIterator()` in async
                let enumerator = snapshot.children
                while let child = enumerator.nextObject() as? DataSnapshot {
                    guard
                        let groupDict = child.value as? [String: Any],
                        let pendingMembers = groupDict["pendingMembers"] as? [String],
                        pendingMembers.contains(userId)
                    else {
                        continue
                    }

                    let groupId    = child.key
                    let groupName  = groupDict["name"] as? String ?? "Unknown Group"
                    let adminId    = groupDict["adminId"] as? String ?? ""
                    let timestamp  = groupDict["createdAt"] as? Double ?? Date().timeIntervalSince1970
                    let adminName  = await self.fetchUsername(for: adminId)

                    invitations.append(
                        GroupInvitation(
                            id:                   groupId,
                            groupId:              groupId,
                            groupName:            groupName,
                            invitedByUserId:      adminId,
                            invitedByUsername:    adminName,
                            timestamp:            timestamp
                        )
                    )
                }

                self.pendingInvitations = invitations
                    .sorted { $0.timestamp > $1.timestamp }
                self.isLoading = false
            }
        }
    }
 
    
    func acceptInvitation(_ invitation: GroupInvitation, userId: String) async {
        do {
            // Use Firebase transaction to ensure atomic updates
            let groupRef = database.child("groups").child(invitation.groupId)
            
            try await groupRef.runTransactionBlock { (currentData) -> TransactionResult in
                guard var groupData = currentData.value as? [String: Any] else {
                    return TransactionResult.abort()
                }
                
                // Remove from pendingMembers
                var pendingMembers = groupData["pendingMembers"] as? [String] ?? []
                pendingMembers.removeAll { $0 == userId }
                
                if pendingMembers.isEmpty {
                    groupData.removeValue(forKey: "pendingMembers")
                } else {
                    groupData["pendingMembers"] = pendingMembers
                }
                
                // Add to members (safely append without overwriting)
                var members = groupData["members"] as? [String] ?? []
                if !members.contains(userId) {
                    members.append(userId)
                }
                groupData["members"] = members
                
                currentData.value = groupData
                return TransactionResult.success(withValue: currentData)
            }
            
            // Add group to user's groups
            let userGroupsRef = database.child("users").child(userId).child("groups")
            let userGroupsSnapshot = try await userGroupsRef.getData()
            var userGroups = userGroupsSnapshot.value as? [String] ?? []
            if !userGroups.contains(invitation.groupId) {
                userGroups.append(invitation.groupId)
                try await userGroupsRef.setValue(userGroups)
            }
            
            // Remove from local list
            pendingInvitations.removeAll { $0.id == invitation.id }
            
        } catch {
            errorMessage = error.localizedDescription
            print("Error accepting invitation: \(error)")
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
            
            // Remove from local list
            pendingInvitations.removeAll { $0.id == invitation.id }
            
        } catch {
            errorMessage = error.localizedDescription
            print("Error declining invitation: \(error)")
        }
    }
    
    private func fetchUsername(for userId: String) async -> String? {
        do {
            let snapshot = try await database.child("users").child(userId).child("username").getData()
            return snapshot.value as? String
        } catch {
            return nil
        }
    }
}
