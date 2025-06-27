//
//  GroupSettingsView.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//

import SwiftUI
import FirebaseAuth

struct GroupSettingsView: View {
    let group: SafetyGroup
    @ObservedObject var groupViewModel: GroupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var editedGroupName: String = ""
    @State private var editedSafetyCheckInterval: Int = 30
    @State private var editedSOSInterval: Int = 5
    @State private var isEditingName = false
    @State private var isEditingIntervals = false
    @State private var showDeleteGroupAlert = false
    @State private var showDeleteMemberAlert = false
    @State private var showCancelInvitationAlert = false
    @State private var memberToDelete: User?
    @State private var invitationToCancel: GroupInvitation?
    @State private var showPendingInvitations = false
    @State private var alertItem: GroupSettingsAlertItem?
    
    let onGroupDeleted: (() -> Void)?
    
    private var isAdmin: Bool {
        guard let currentUserId = authViewModel.currentUser?.id else { return false }
        return currentUserId == group.adminId
    }
    
    private var currentUserId: String {
        return authViewModel.currentUser?.id ?? ""
    }
    
    // Use current group state for real-time updates
    private var currentGroup: SafetyGroup {
        return groupViewModel.groups.first { $0.id == group.id } ?? group
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Group Information Section
                Section("Group Information") {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(.blue)
                        
                        if isEditingName {
                            TextField("Group name", text: $editedGroupName)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentGroup.name)
                                    .font(.headline)
                                Text("\(currentGroup.members.count) members")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if isAdmin {
                            Button {
                                if isEditingName {
                                    saveGroupName()
                                } else {
                                    startEditingName()
                                }
                            } label: {
                                Text(isEditingName ? "Save" : "Edit")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // MARK: - Settings Section
                Section("Settings") {
                    // Safety Check Interval
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Safety Check Interval")
                            Text("Time between safety checks")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if isEditingIntervals {
                            HStack {
                                TextField("Minutes", value: $editedSafetyCheckInterval, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .keyboardType(.numberPad)
                                Text("min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("\(currentGroup.safetyCheckInterval) minutes")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // SOS Interval
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SOS Interval")
                            Text("Time between SOS alerts")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if isEditingIntervals {
                            HStack {
                                TextField("Minutes", value: $editedSOSInterval, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .keyboardType(.numberPad)
                                Text("min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("\(currentGroup.sosInterval) minutes")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Edit Intervals Button (Admin Only)
                    if isAdmin {
                        HStack {
                            Spacer()
                            Button {
                                if isEditingIntervals {
                                    saveIntervals()
                                } else {
                                    startEditingIntervals()
                                }
                            } label: {
                                Text(isEditingIntervals ? "Save Intervals" : "Edit Intervals")
                                    .font(.callout)
                            }
                            .buttonStyle(.bordered)
                            
                            if isEditingIntervals {
                                Button("Cancel") {
                                    cancelEditingIntervals()
                                }
                                .buttonStyle(.bordered)
                            }
                            Spacer()
                        }
                    }
                }
                
                // MARK: - Pending Invitations Section (Admin Only)
                if isAdmin {
                    Section("Pending Invitations") {
                        Button {
                            loadPendingInvitations()
                        } label: {
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundStyle(.blue)
                                Text("View Pending Invitations")
                                Spacer()
                                
                                // Pending invitations badge
                                if !groupViewModel.pendingInvitations.isEmpty {
                                    Text("\(groupViewModel.pendingInvitations.count)")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                }
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // MARK: - Members Section
                Section("Members") {
                    ForEach(groupViewModel.groupMembers) { member in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(member.id == currentUserId ? Color.green : Color.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(member.username)
                                        .fontWeight(.medium)
                                    
                                    if member.id == currentUserId {
                                        Text("(You)")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.2))
                                            .foregroundStyle(Color.green)
                                            .cornerRadius(4)
                                    }
                                    
                                    if member.id == group.adminId {
                                        Text("Admin")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.2))
                                            .foregroundStyle(Color.blue)
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Text(member.phoneNumber)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            
                            Spacer()
                            
                            // Admin can delete members (except themselves)
                            if isAdmin && member.id != currentUserId {
                                Button {
                                    memberToDelete = member
                                    showDeleteMemberAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Danger Zone (Admin Only)
                if isAdmin {
                    Section("Danger Zone") {
                        Button {
                            showDeleteGroupAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundStyle(.red)
                                Text("Delete Group")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Group Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                editedGroupName = currentGroup.name
                editedSafetyCheckInterval = currentGroup.safetyCheckInterval
                editedSOSInterval = currentGroup.sosInterval
                Task {
                    await groupViewModel.loadGroupMembers(group: currentGroup)
                }
            }
            .onChange(of: currentGroup.name) { _, newName in
                if !isEditingName {
                    editedGroupName = newName
                }
            }
            .onChange(of: currentGroup.safetyCheckInterval) { _, newInterval in
                if !isEditingIntervals {
                    editedSafetyCheckInterval = newInterval
                }
            }
            .onChange(of: currentGroup.sosInterval) { _, newInterval in
                if !isEditingIntervals {
                    editedSOSInterval = newInterval
                }
            }
            .sheet(isPresented: $showPendingInvitations) {
                PendingInvitationsView(
                    group: currentGroup,
                    groupViewModel: groupViewModel
                )
            }
            .alert("Delete Member", isPresented: $showDeleteMemberAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let member = memberToDelete {
                        deleteMember(member)
                    }
                }
            } message: {
                if let member = memberToDelete {
                    Text("Are you sure you want to remove @\(member.username) from the group?")
                }
            }
            .alert("Delete Group", isPresented: $showDeleteGroupAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteGroup()
                }
            } message: {
                Text("Are you sure you want to delete '\(currentGroup.name)'? This action cannot be undone and will remove all members from the group.")
            }
            .alert("Cancel Invitation", isPresented: $showCancelInvitationAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    if let invitation = invitationToCancel {
                        cancelInvitation(invitation)
                    }
                }
            } message: {
                if let invitation = invitationToCancel {
                    Text("Are you sure you want to cancel the invitation for @\(invitation.invitedUsername ?? "Unknown User")?")
                }
            }
            .alert(item: $alertItem) { item in
                Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func startEditingName() {
        editedGroupName = currentGroup.name
        isEditingName = true
    }
    
    private func saveGroupName() {
        let trimmedName = editedGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            alertItem = GroupSettingsAlertItem(
                title: "Invalid Name",
                message: "Group name cannot be empty."
            )
            return
        }
        
        guard trimmedName != currentGroup.name else {
            isEditingName = false
            return
        }
        
        Task {
            await groupViewModel.updateGroupName(
                groupId: currentGroup.id,
                newName: trimmedName,
                adminId: currentUserId
            )
            
            await MainActor.run {
                if groupViewModel.errorMessage == nil {
                    isEditingName = false
                } else {
                    alertItem = GroupSettingsAlertItem(
                        title: "Error",
                        message: groupViewModel.errorMessage ?? "Failed to update group name"
                    )
                }
            }
        }
    }
    
    private func startEditingIntervals() {
        editedSafetyCheckInterval = currentGroup.safetyCheckInterval
        editedSOSInterval = currentGroup.sosInterval
        isEditingIntervals = true
    }
    
    private func saveIntervals() {
        // Validate intervals
        guard editedSafetyCheckInterval >= 1 && editedSafetyCheckInterval <= 1440 else {
            alertItem = GroupSettingsAlertItem(
                title: "Invalid Safety Check Interval",
                message: "Safety check interval must be between 1 and 1440 minutes (24 hours)."
            )
            return
        }
        
        guard editedSOSInterval >= 1 && editedSOSInterval <= 60 else {
            alertItem = GroupSettingsAlertItem(
                title: "Invalid SOS Interval",
                message: "SOS interval must be between 1 and 60 minutes."
            )
            return
        }
        
        // Check if values actually changed
        guard editedSafetyCheckInterval != currentGroup.safetyCheckInterval || editedSOSInterval != currentGroup.sosInterval else {
            isEditingIntervals = false
            return
        }
        
        Task {
            // Update safety check interval if changed
            if editedSafetyCheckInterval != currentGroup.safetyCheckInterval {
                await groupViewModel.updateSafetyCheckInterval(
                    groupId: currentGroup.id,
                    newInterval: editedSafetyCheckInterval,
                    adminId: currentUserId
                )
            }
            
            // Update SOS interval if changed
            if editedSOSInterval != currentGroup.sosInterval {
                await groupViewModel.updateSOSInterval(
                    groupId: currentGroup.id,
                    newInterval: editedSOSInterval,
                    adminId: currentUserId
                )
            }
            
            await MainActor.run {
                if groupViewModel.errorMessage == nil {
                    isEditingIntervals = false
                } else {
                    alertItem = GroupSettingsAlertItem(
                        title: "Error",
                        message: groupViewModel.errorMessage ?? "Failed to update intervals"
                    )
                }
            }
        }
    }
    
    private func cancelEditingIntervals() {
        editedSafetyCheckInterval = currentGroup.safetyCheckInterval
        editedSOSInterval = currentGroup.sosInterval
        isEditingIntervals = false
    }
    
    private func loadPendingInvitations() {
        Task {
            await groupViewModel.loadPendingInvitations(groupId: currentGroup.id)
            await MainActor.run {
                showPendingInvitations = true
            }
        }
    }
    
    private func deleteMember(_ member: User) {
        Task {
            await groupViewModel.removeMemberFromGroup(
                groupId: currentGroup.id,
                memberIdToRemove: member.id,
                adminId: currentUserId
            )
            
            await MainActor.run {
                if let error = groupViewModel.errorMessage {
                    alertItem = GroupSettingsAlertItem(
                        title: "Error",
                        message: error
                    )
                }
            }
        }
    }
    
    private func deleteGroup() {
        Task {
            await groupViewModel.deleteGroup(
                groupId: currentGroup.id,
                adminId: currentUserId
            )
            
            await MainActor.run {
                if groupViewModel.errorMessage == nil {
                    // Successfully deleted - dismiss all navigation
                    dismiss()
                    onGroupDeleted?()
                } else {
                    alertItem = GroupSettingsAlertItem(
                        title: "Error",
                        message: groupViewModel.errorMessage ?? "Failed to delete group"
                    )
                }
            }
        }
    }
    
    private func cancelInvitation(_ invitation: GroupInvitation) {
        Task {
            await groupViewModel.cancelInvitation(
                invitationId: invitation.id,
                groupId: currentGroup.id,
                invitedUserId: invitation.invitedUserId,
                adminId: currentGroup.adminId
            )
        }
    }
}

// MARK: - Alert Helper
struct GroupSettingsAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
