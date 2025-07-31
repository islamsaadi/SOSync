import SwiftUI


struct PendingInvitationsView: View {
    let group: SafetyGroup
    @ObservedObject var groupViewModel: GroupViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showCancelInvitationAlert = false
    @State private var invitationToCancel: GroupInvitation?
    
    var body: some View {
        NavigationStack {
            List {
                if groupViewModel.pendingInvitations.isEmpty {
                    ContentUnavailableView {
                        Label("No Pending Invitations", systemImage: "envelope")
                    } description: {
                        Text("This group has no pending invitations")
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(groupViewModel.pendingInvitations) { invitation in
                        PendingInvitationRowView(
                            invitation: invitation,
                            onCancel: {
                                invitationToCancel = invitation
                                showCancelInvitationAlert = true
                            }
                        )
                    }
                }
            }
            .navigationTitle("Pending Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await groupViewModel.loadPendingInvitations(groupId: group.id)
                }
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
        }
    }
    
    private func cancelInvitation(_ invitation: GroupInvitation) {
        Task {
            await groupViewModel.cancelInvitation(
                invitationId: invitation.id,
                groupId: group.id,
                invitedUserId: invitation.invitedUserId,
                adminId: group.adminId
            )
        }
    }
}

struct PendingInvitationRowView: View {
    let invitation: GroupInvitation
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "person.badge.plus")
                .font(.title2)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                if let username = invitation.invitedUsername {
                    Text("@\(username)")
                        .font(.headline)
                } else {
                    Text("User ID: \(invitation.invitedUserId)")
                        .font(.headline)
                }
                
                Text("Invited \(Date(timeIntervalSince1970: invitation.timestamp), style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
        }
        .padding(.vertical, 4)
    }
}
