//
//  SafetyCheck.swift
//  SOSync
//
//  Created by Islam Saadi on 26/06/2025.
//

// Safety Check model
struct SafetyCheck: Identifiable, Codable {
    let id: String
    let groupId: String
    let initiatedBy: String
    let timestamp: Double
    var responses: [String: SafetyResponse] = [:] // userId: response
    var status: SafetyCheckStatus = .pending
    
    // Custom decoder to handle missing responses field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        groupId = try container.decode(String.self, forKey: .groupId)
        initiatedBy = try container.decode(String.self, forKey: .initiatedBy)
        timestamp = try container.decode(Double.self, forKey: .timestamp)
        status = try container.decodeIfPresent(SafetyCheckStatus.self, forKey: .status) ?? .pending
        
        // Handle missing responses field by trying to decode directly as SafetyResponse dictionary
        if let responsesDict = try? container.decodeIfPresent([String: SafetyResponse].self, forKey: .responses) {
            responses = responsesDict
        } else {
            responses = [:] // Default to empty if responses field doesn't exist or can't be decoded
        }
    }
    
    // Regular initializer
    init(id: String, groupId: String, initiatedBy: String, timestamp: Double) {
        self.id = id
        self.groupId = groupId
        self.initiatedBy = initiatedBy
        self.timestamp = timestamp
        self.responses = [:]
        self.status = .pending
    }
    
    var dictionary: [String: Any] {
        var responsesDict: [String: [String: Any]] = [:]
        for (userId, response) in responses {
            responsesDict[userId] = response.dictionary
        }
        
        var dict: [String: Any] = [
            "id": id,
            "groupId": groupId,
            "initiatedBy": initiatedBy,
            "timestamp": timestamp,
            "status": status.rawValue
        ]
        
        // Only add responses if there are any
        if !responsesDict.isEmpty {
            dict["responses"] = responsesDict
        }
        
        return dict
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, groupId, initiatedBy, timestamp, responses, status
    }
}

enum SafetyCheckStatus: String, Codable {
    case pending = "pending"
    case allSafe = "allSafe"
    case emergency = "emergency"
}
