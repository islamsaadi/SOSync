//
//  GroupInvitation.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//

import Foundation

struct GroupInvitation: Identifiable, Codable {
    let id: String
    let groupId: String
    let groupName: String
    let invitedUserId: String
    let invitedUsername: String?
    let invitedByUserId: String
    let invitedByUsername: String?
    let invitedByPhone: String?
    let timestamp: Double
    
    init(
        id: String,
        groupId: String,
        groupName: String,
        invitedUserId: String = "",
        invitedUsername: String? = nil,
        invitedByUserId: String,
        invitedByUsername: String? = nil,
        invitedByPhone: String? = nil,
        timestamp: Double
    ) {
        self.id = id
        self.groupId = groupId
        self.groupName = groupName
        self.invitedUserId = invitedUserId
        self.invitedUsername = invitedUsername
        self.invitedByUserId = invitedByUserId
        self.invitedByUsername = invitedByUsername
        self.invitedByPhone = invitedByPhone
        self.timestamp = timestamp
    }
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "groupId": groupId,
            "groupName": groupName,
            "invitedUserId": invitedUserId,
            "invitedByUserId": invitedByUserId,
            "timestamp": timestamp
        ]
        
        if let invitedUsername = invitedUsername {
            dict["invitedUsername"] = invitedUsername
        }
        
        if let invitedByUsername = invitedByUsername {
            dict["invitedByUsername"] = invitedByUsername
        }
        
        if let invitedByPhone = invitedByPhone {
            dict["invitedByPhone"] = invitedByPhone
        }
        
        return dict
    }
}
