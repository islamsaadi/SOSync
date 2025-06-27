//
//  MemberRowView.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//

import SwiftUI

struct MemberRowView: View {
    let member: User
    let isAdmin: Bool
    let isCurrentUser: Bool
    let canRemoveMember: Bool
    let onRemoveMember: (() -> Void)?
    
    init(
        member: User,
        isAdmin: Bool,
        isCurrentUser: Bool,
        canRemoveMember: Bool = false,
        onRemoveMember: (() -> Void)? = nil
    ) {
        self.member = member
        self.isAdmin = isAdmin
        self.isCurrentUser = isCurrentUser
        self.canRemoveMember = canRemoveMember
        self.onRemoveMember = onRemoveMember
    }
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(isCurrentUser ? Color.green : Color.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.username)
                        .fontWeight(.medium)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(Color.green)
                            .cornerRadius(4)
                    }
                    
                    if isAdmin {
                        Text("Admin")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(Color.blue)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    // Remove member button (only for admins, and not for themselves)
                    if canRemoveMember && !isCurrentUser {
                        Button {
                            onRemoveMember?()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                Text(member.phoneNumber)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}
