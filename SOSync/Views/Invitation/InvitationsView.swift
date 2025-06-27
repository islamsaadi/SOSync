//
//  InvitationsView.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//

import SwiftUI
import FirebaseAuth

struct InvitationsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = InvitationsViewModel(
        userId: Auth.auth().currentUser?.uid ?? ""
    )
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.pendingInvitations.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView {
                        Label("No Invitations", systemImage: "envelope")
                    } description: {
                        Text("You don't have any pending group invitations")
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.pendingInvitations) { invitation in
                        EnhancedInvitationRowView(
                            invitation: invitation,
                            onAccept: {
                                acceptInvitation(invitation)
                            },
                            onDecline: {
                                declineInvitation(invitation)
                            }
                        )
                        .disabled(isProcessing)
                    }
                }
            }
            .navigationTitle("Invitations")
            .refreshable {
                if let userId = authViewModel.currentUser?.id {
                    await viewModel.loadPendingInvitations(for: userId)
                }
            }
            .onAppear {
                Task {
                    if let userId = authViewModel.currentUser?.id {
                        await viewModel.loadPendingInvitations(for: userId)
                    }
                }
            }
        }
    }
    
    private func acceptInvitation(_ invitation: GroupInvitation) {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isProcessing = true
        Task {
            await viewModel.acceptInvitation(invitation, userId: userId)
            isProcessing = false
        }
    }
    
    private func declineInvitation(_ invitation: GroupInvitation) {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isProcessing = true
        Task {
            await viewModel.declineInvitation(invitation, userId: userId)
            isProcessing = false
        }
    }
}

struct EnhancedInvitationRowView: View {
    let invitation: GroupInvitation
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(invitation.groupName)
                        .font(.headline)
                    
                    // Enhanced inviter information
                    VStack(alignment: .leading, spacing: 2) {
                        if let invitedBy = invitation.invitedByUsername {
                            Text("Invited by @\(invitedBy)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let inviterPhone = invitation.invitedByPhone {
                            Text("Phone: \(inviterPhone)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text("Invited \(Date(timeIntervalSince1970: invitation.timestamp), style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button {
                    onDecline()
                } label: {
                    Text("Decline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button {
                    onAccept()
                } label: {
                    Text("Accept")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 8)
    }
}
