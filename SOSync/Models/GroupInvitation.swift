//
//  GroupInvitation.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//


// Data model for invitations
struct GroupInvitation: Identifiable {
    let id: String
    let groupId: String
    let groupName: String
    let invitedByUserId: String
    let invitedByUsername: String?
    let timestamp: Double
}