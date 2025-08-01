struct SOSAlert: Identifiable, Codable {
    let id: String
    let userId: String
    let groupId: String
    let timestamp: Double
    let location: LocationData
    let message: String?
    var isActive: Bool = true
    
    var resolvedAt: Double?
    var resolvedReason: String?
    
    init(id: String, userId: String, groupId: String, timestamp: Double, location: LocationData, message: String? = nil) {
        self.id = id
        self.userId = userId
        self.groupId = groupId
        self.timestamp = timestamp
        self.location = location
        self.message = message
        self.isActive = true
        self.resolvedAt = nil
        self.resolvedReason = nil
    }
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "userId": userId,
            "groupId": groupId,
            "timestamp": timestamp,
            "location": location.dictionary,
            "isActive": isActive
        ]
        
        if let message = message {
            dict["message"] = message
        }
        
        if let resolvedAt = resolvedAt {
            dict["resolvedAt"] = resolvedAt
        }
        
        if let resolvedReason = resolvedReason {
            dict["resolvedReason"] = resolvedReason
        }
        
        return dict
    }
    
    var isResolved: Bool {
        return !isActive || resolvedAt != nil
    }
}
