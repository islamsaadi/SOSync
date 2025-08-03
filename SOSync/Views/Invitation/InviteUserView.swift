import SwiftUI

struct InviteUserView: View {
    let group: SafetyGroup
    @ObservedObject var groupViewModel: GroupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel = InviteUserViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Search field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search by username (@username) or phone number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("@username or phone", text: $viewModel.searchQuery)
                                .textInputAutocapitalization(.never)
                                .onChange(of: viewModel.searchQuery) { _, _ in
                                    viewModel.validateSearchQuery()
                                }
                            
                            Button("Search") {
                                searchUser()
                            }
                            .disabled(!viewModel.canSearch)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        
                        // Validation error
                        if let validationError = viewModel.validationError {
                            Text(validationError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Search result
                if let user = viewModel.foundUser {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("User Found")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("@\(user.username)")
                                    .fontWeight(.medium)
                                Text(user.phoneNumber)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Invite") {
                                inviteUser()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Search error
                if let error = viewModel.searchError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Loading indicator
                if viewModel.isSearching {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Searching...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to search:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• For username: @johnsmith")
                        Text("• For phone: +1234567890 or 1234567890")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationTitle("Invite User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.setupWith(
                    authViewModel: authViewModel,
                    group: group
                )
            }
        }
    }
    
    private func searchUser() {
        Task {
            await viewModel.searchUser()
        }
    }
    
    private func inviteUser() {
        guard let user = viewModel.foundUser,
              let currentUserId = authViewModel.currentUser?.id else { return }
        
        Task {
            await groupViewModel.inviteUserToGroup(
                groupId: group.id,
                invitedUserId: user.id,
                inviterUserId: currentUserId
            )
            await MainActor.run {
                dismiss()
            }
        }
    }
}
