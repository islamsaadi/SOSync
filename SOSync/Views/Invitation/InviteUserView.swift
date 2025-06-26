//
//  InviteUserView.swift
//  SOSync
//
//  Created by Islam Saadi on 22/06/2025.
//

import SwiftUI

struct InviteUserView: View {
    let group: SafetyGroup
    @ObservedObject var groupViewModel: GroupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var searchQuery = ""
    @State private var foundUser: User?
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var validationError: String?
    
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
                            TextField("@username or phone", text: $searchQuery)
                                .textInputAutocapitalization(.never)
                                .onChange(of: searchQuery) { _, newValue in
                                    // Clear previous results when user types
                                    foundUser = nil
                                    searchError = nil
                                    
                                    // Validate input in real-time
                                    let validation = authViewModel.validateSearchQuery(newValue)
                                    switch validation {
                                    case .valid:
                                        validationError = nil
                                    case .invalid(let error):
                                        validationError = newValue.isEmpty ? nil : error
                                    }
                                }
                            
                            Button("Search") {
                                searchUser()
                            }
                            .disabled(searchQuery.isEmpty || isSearching || validationError != nil)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        
                        // Validation error
                        if let validationError = validationError {
                            Text(validationError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Search result
                if let user = foundUser {
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
                if let error = searchError {
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
                if isSearching {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Searching...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Helper text
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
        }
    }
    
    private func searchUser() {
        // Validate input before searching
        let validation = authViewModel.validateSearchQuery(searchQuery)
        switch validation {
        case .invalid(let error):
            searchError = error
            return
        case .valid:
            break
        }
        
        isSearching = true
        searchError = nil
        foundUser = nil
        
        Task {
            do {
                let user = await authViewModel.searchUser(by: searchQuery)
                await MainActor.run {
                    if let user = user {
                        // Check if user is already in group
                        if group.members.contains(user.id) {
                            searchError = "User is already a member of this group"
                            foundUser = nil
                        } else if let pendingMembers = group.pendingMembers, pendingMembers.contains(user.id) {
                            // Safely unwrap and check pendingMembers
                            searchError = "User has already been invited"
                            foundUser = nil
                        } else {
                            foundUser = user
                            searchError = nil
                        }
                    } else {
                        searchError = "No user found with that username or phone number"
                        foundUser = nil
                    }
                    isSearching = false
                }
            }
        }
    }
    
    private func inviteUser() {
        guard let user = foundUser else { return }
        
        Task {
            await groupViewModel.inviteUserToGroup(groupId: group.id, invitedUserId: user.id)
            await MainActor.run {
                dismiss()
            }
        }
    }
}
